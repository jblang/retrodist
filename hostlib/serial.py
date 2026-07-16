"""Manage buffered installer communication over QEMU's automation serial port.

One background task drains ``ttyS3.sock`` into an append-only text buffer and a
raw log. Wait operations advance an independent consumption offset, allowing
dialog automation to mark and rewind input without losing the transcript.
Keyboard answers echoed by the guest are recognized and omitted from guest
output logging.
"""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path
import re
from typing import BinaryIO

log = logging.getLogger(__name__)


class SerialConsole:
    """Asynchronous connection to QEMU's install-automation serial socket.

    The console separates receipt, consumption, and transcript offsets. This
    lets concurrent QEMU output continue accumulating while synchronous driver
    code waits for exact text, complete lines, regular expressions, or one of
    several alternative prompts.
    """

    def __init__(
        self, socket: Path, *, log_path: Path | None = None, connect_timeout: float = 10
    ) -> None:
        """Initialize buffering and connection state for a serial socket."""
        self.socket = socket
        self.log_path = log_path or socket.with_suffix(".log")
        self.connect_timeout = connect_timeout
        self._reader: asyncio.StreamReader | None = None
        self._writer: asyncio.StreamWriter | None = None
        self._buffer = ""
        self._offset = 0
        self._transcript_offset = 0
        self._echoes: list[str] = []
        self._changed = asyncio.Condition()
        self._drain_task: asyncio.Task[None] | None = None
        self._failure: BaseException | None = None
        self._log_file: BinaryIO | None = None

    async def start(self) -> None:
        """Connect to QEMU's serial socket and start its reader task."""
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.connect_timeout
        while True:
            try:
                self._reader, self._writer = await asyncio.open_unix_connection(self.socket)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if loop.time() >= deadline:
                    raise TimeoutError(f"Timed out connecting to serial socket {self.socket}")
                await asyncio.sleep(0.05)
        self._log_file = self.log_path.open("wb")
        self._drain_task = asyncio.create_task(self._drain(), name="serial-console-reader")

    async def close(self) -> None:
        """Close serial streams, reader task, and transcript file."""
        if self._writer:
            self._writer.close()
            await self._writer.wait_closed()
        if self._drain_task:
            self._drain_task.cancel()
            await asyncio.gather(self._drain_task, return_exceptions=True)
        self._emit_transcript(len(self._buffer))
        if self._log_file:
            self._log_file.close()
            self._log_file = None

    async def _drain(self) -> None:
        """Continuously append serial bytes to the buffer and transcript."""
        assert self._reader is not None
        try:
            while chunk := await self._reader.read(4096):
                if self._log_file:
                    self._log_file.write(chunk)
                    self._log_file.flush()
                text = chunk.decode(errors="replace").replace("\r", "")
                log.debug("Guest serial output: %r", text)
                async with self._changed:
                    self._buffer += text
                    complete = self._buffer.rfind("\n") + 1
                    self._emit_transcript(complete)
                    self._changed.notify_all()
        except asyncio.CancelledError:
            raise
        except BaseException as exc:
            self._failure = exc
        finally:
            if self._failure is None:
                self._failure = EOFError("QEMU closed the serial console")
            async with self._changed:
                self._changed.notify_all()

    async def send(self, text: str) -> None:
        """Write a newline-terminated answer to the guest serial port."""
        if self._writer is None:
            raise RuntimeError("Serial console is not connected")
        self._emit_transcript(len(self._buffer))
        log.debug("Guest serial input: %r", text)
        self._echoes.append(text)
        try:
            self._writer.write(f"{text}\n".encode())
            await self._writer.drain()
        except BaseException:
            if self._echoes and self._echoes[-1] == text:
                self._echoes.pop()
            raise
        log.info("⬅️  %s", text)

    def _emit_transcript(self, end: int, matched: int | None = None) -> None:
        """Log newly consumed guest output and an optional matched prompt.

        Ordinary guest lines use ``➡️`` and the line containing a successful
        prompt match uses ``✅``. Echoed answers are suppressed because ``send``
        already records host responses with ``⬅️``.
        """
        start = self._transcript_offset
        if end <= start:
            return
        cursor = start
        for raw in self._buffer[start:end].splitlines(keepends=True):
            line = raw.rstrip("\n")
            line_end = cursor + len(raw)
            echo = next((i for i, value in enumerate(self._echoes) if value == line), None)
            if echo is not None:
                del self._echoes[: echo + 1]
            else:
                marker = "✅" if matched is not None and cursor <= matched < line_end else "➡️ "
                log.info("%s %s", marker, line)
            cursor = line_end
        self._transcript_offset = end

    def _line_end(self, matched_end: int) -> int:
        """Consume the complete serial line containing a matched prompt."""
        newline = self._buffer.find("\n", matched_end)
        return newline + 1 if newline >= 0 else len(self._buffer)

    async def wait(
        self,
        expected: str,
        *,
        line: bool = False,
        regex: bool = False,
        timeout: float | None = None,
    ) -> str:
        """Consume serial input through one expected prompt.

        Args:
            expected: Literal text or regular expression to match.
            line: Require ``expected`` to occupy a complete trimmed line.
            regex: Interpret ``expected`` as a regular expression.
            timeout: Optional maximum wait in seconds.

        Returns:
            The exact text matched in the serial buffer.
        """
        pattern = self._wait_pattern(expected, line=line, regex=regex)
        if timeout is None:
            return await self._wait_one(pattern)
        async with asyncio.timeout(timeout):
            return await self._wait_one(pattern)

    @staticmethod
    def _wait_pattern(expected: str, *, line: bool, regex: bool) -> re.Pattern[str]:
        """Compile a literal, complete-line, or regular-expression wait pattern."""
        if line:
            return re.compile(rf"(?m)^\s*{re.escape(expected.strip())}\s*$")
        return re.compile(expected if regex else re.escape(expected), re.MULTILINE)

    async def _wait_one(self, pattern: re.Pattern[str]) -> str:
        """Poll buffered serial input until one compiled pattern matches."""
        while True:
            start = self._offset
            if match := pattern.search(self._buffer[start:]):
                matched_start = start + match.start()
                self._offset = self._line_end(start + match.end())
                self._emit_transcript(self._offset, matched_start)
                return match.group()
            if self._failure:
                raise self._failure
            async with self._changed:
                await self._changed.wait()

    async def wait_any(
        self,
        patterns: tuple[str, ...],
        *,
        regex: bool = False,
        timeout: float | None = None,
    ) -> tuple[int, str]:
        """Consume input through the earliest of several prompt patterns.

        Returns:
            A pair containing the winning pattern index and matched text.
        """
        compiled = tuple(
            re.compile(value if regex else re.escape(value), re.MULTILINE) for value in patterns
        )

        if timeout is None:
            return await self._wait_first(compiled)
        async with asyncio.timeout(timeout):
            return await self._wait_first(compiled)

    async def _wait_first(self, patterns: tuple[re.Pattern[str], ...]) -> tuple[int, str]:
        """Poll until the earliest match among several compiled patterns."""
        while True:
            start = self._offset
            matches = (
                (i, match)
                for i, pattern in enumerate(patterns)
                if (match := pattern.search(self._buffer[start:]))
            )
            try:
                index, match = min(matches, key=lambda item: item[1].start())
            except ValueError:
                if self._failure:
                    raise self._failure
                async with self._changed:
                    await self._changed.wait()
                continue
            matched_start = start + match.start()
            self._offset = self._line_end(start + match.end())
            self._emit_transcript(self._offset, matched_start)
            return index, match.group()

    async def read_until(self, pattern: re.Pattern[str]) -> str:
        """Consume and return serial text through the next regex match."""
        while True:
            start = self._offset
            if match := pattern.search(self._buffer[start:]):
                matched_start = start + match.start()
                self._offset = start + match.end()
                self._emit_transcript(self._offset, matched_start)
                return self._buffer[start : self._offset]
            if self._failure:
                raise self._failure
            async with self._changed:
                await self._changed.wait()

    async def mark(self) -> int:
        """Return the current serial-consumption offset."""
        return self._offset

    async def rewind(self, offset: int) -> None:
        """Restore the serial-consumption offset to an earlier mark."""
        if not 0 <= offset <= len(self._buffer):
            raise ValueError("Invalid serial buffer offset")
        self._offset = offset

    async def prompt(self, *questions: str, answer: str, regex: bool = False) -> None:
        """Wait for each question in order, then send one answer."""
        for question in questions:
            await self.wait(question, regex=regex)
        await self.send(answer)
