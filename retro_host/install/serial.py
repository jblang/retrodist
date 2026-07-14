from __future__ import annotations

import asyncio
import logging
from pathlib import Path
import re
from typing import BinaryIO

log = logging.getLogger(__name__)


class SerialConsole:
    """Async connection to QEMU's install-automation serial socket."""

    def __init__(
        self, socket: Path, *, log_path: Path | None = None, connect_timeout: float = 10
    ) -> None:
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
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.connect_timeout
        while True:
            try:
                self._reader, self._writer = await asyncio.open_unix_connection(
                    self.socket
                )
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if loop.time() >= deadline:
                    raise TimeoutError(
                        f"Timed out connecting to serial socket {self.socket}"
                    )
                await asyncio.sleep(0.05)
        self._log_file = self.log_path.open("wb")
        self._drain_task = asyncio.create_task(
            self._drain(), name="serial-console-reader"
        )

    async def close(self) -> None:
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
        if line:
            pattern = re.compile(rf"(?m)^\s*{re.escape(expected.strip())}\s*$")
        elif regex:
            pattern = re.compile(expected, re.MULTILINE)
        else:
            pattern = re.compile(re.escape(expected))

        async def waiting() -> str:
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

        if timeout is None:
            return await waiting()
        async with asyncio.timeout(timeout):
            return await waiting()

    async def wait_any(
        self, patterns: tuple[str, ...], *, regex: bool = False, timeout: float | None = None
    ) -> tuple[int, str]:
        compiled = tuple(
            re.compile(value if regex else re.escape(value), re.MULTILINE)
            for value in patterns
        )

        async def waiting() -> tuple[int, str]:
            while True:
                start = self._offset
                remaining = self._buffer[start:]
                matches = (
                    (i, match)
                    for i, pattern in enumerate(compiled)
                    if (match := pattern.search(remaining))
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

        if timeout is None:
            return await waiting()
        async with asyncio.timeout(timeout):
            return await waiting()

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
        return self._offset

    async def rewind(self, offset: int) -> None:
        if not 0 <= offset <= len(self._buffer):
            raise ValueError("Invalid serial buffer offset")
        self._offset = offset

    async def prompt(
        self, *questions: str, answer: str, regex: bool = False
    ) -> None:
        for question in questions:
            await self.wait(question, regex=regex)
        await self.send(answer)
