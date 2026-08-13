#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
from contextlib import suppress
from dataclasses import dataclass


MAX_HEADER_BYTES = 8192
HEADER_TIMEOUT_SECONDS = 5.0
UPSTREAM_CONNECT_TIMEOUT_SECONDS = 10.0
TUNNEL_IDLE_TIMEOUT_SECONDS = 60.0
BUFFER_SIZE = 65536


@dataclass(frozen=True)
class Config:
    listen_host: str
    listen_port: int
    allowed_peer: str
    target_host: str
    target_port: int

    @property
    def authority(self) -> str:
        return f"{self.target_host}:{self.target_port}"


def _args() -> Config:
    parser = argparse.ArgumentParser(description="Bounded HTTP CONNECT relay for MOEX Telegram egress")
    parser.add_argument("--listen-host", required=True)
    parser.add_argument("--listen-port", required=True, type=int)
    parser.add_argument("--allowed-peer", required=True)
    parser.add_argument("--target-host", required=True)
    parser.add_argument("--target-port", required=True, type=int)
    ns = parser.parse_args()
    if not 1 <= ns.listen_port <= 65535:
        parser.error("listen port out of range")
    if not 1 <= ns.target_port <= 65535:
        parser.error("target port out of range")
    return Config(
        listen_host=ns.listen_host,
        listen_port=ns.listen_port,
        allowed_peer=ns.allowed_peer,
        target_host=ns.target_host,
        target_port=ns.target_port,
    )


async def _read_header(reader: asyncio.StreamReader) -> bytes:
    data = bytearray()
    while b"\r\n\r\n" not in data:
        if len(data) >= MAX_HEADER_BYTES:
            raise ValueError("header_too_large")
        chunk = await asyncio.wait_for(
            reader.read(min(1024, MAX_HEADER_BYTES - len(data))),
            timeout=HEADER_TIMEOUT_SECONDS,
        )
        if not chunk:
            raise ValueError("header_eof")
        data.extend(chunk)
    end = data.index(b"\r\n\r\n") + 4
    if end != len(data):
        raise ValueError("unexpected_payload_before_tunnel")
    return bytes(data)


def _validate_connect(header: bytes, expected_authority: str) -> None:
    try:
        first_line = header.split(b"\r\n", 1)[0].decode("ascii", "strict")
    except UnicodeError as exc:
        raise ValueError("non_ascii_request_line") from exc
    parts = first_line.split(" ")
    if len(parts) != 3:
        raise ValueError("invalid_request_line")
    method, authority, version = parts
    if method != "CONNECT":
        raise PermissionError("method_not_allowed")
    if authority.lower() != expected_authority.lower():
        raise PermissionError("target_not_allowed")
    if version not in {"HTTP/1.0", "HTTP/1.1"}:
        raise ValueError("http_version_not_supported")


async def _respond(writer: asyncio.StreamWriter, status: str) -> None:
    writer.write(f"HTTP/1.1 {status}\r\nConnection: close\r\n\r\n".encode("ascii"))
    await writer.drain()


async def _pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    while True:
        chunk = await asyncio.wait_for(reader.read(BUFFER_SIZE), timeout=TUNNEL_IDLE_TIMEOUT_SECONDS)
        if not chunk:
            with suppress(Exception):
                writer.write_eof()
                await writer.drain()
            return
        writer.write(chunk)
        await writer.drain()


async def _tunnel(
    client_reader: asyncio.StreamReader,
    client_writer: asyncio.StreamWriter,
    upstream_reader: asyncio.StreamReader,
    upstream_writer: asyncio.StreamWriter,
) -> None:
    tasks = {
        asyncio.create_task(_pipe(client_reader, upstream_writer)),
        asyncio.create_task(_pipe(upstream_reader, client_writer)),
    }
    try:
        await asyncio.gather(*tasks)
    finally:
        for task in tasks:
            task.cancel()
        for task in tasks:
            with suppress(asyncio.CancelledError, Exception):
                await task


async def _handle(
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
    config: Config,
) -> None:
    peer = writer.get_extra_info("peername")
    peer_ip = peer[0] if isinstance(peer, tuple) and peer else None
    if peer_ip != config.allowed_peer:
        with suppress(Exception):
            await _respond(writer, "403 Forbidden")
        writer.close()
        with suppress(Exception):
            await writer.wait_closed()
        return

    try:
        header = await _read_header(reader)
        _validate_connect(header, config.authority)
    except PermissionError:
        with suppress(Exception):
            await _respond(writer, "403 Forbidden")
        writer.close()
        with suppress(Exception):
            await writer.wait_closed()
        return
    except (ValueError, asyncio.TimeoutError):
        with suppress(Exception):
            await _respond(writer, "400 Bad Request")
        writer.close()
        with suppress(Exception):
            await writer.wait_closed()
        return

    try:
        upstream_reader, upstream_writer = await asyncio.wait_for(
            asyncio.open_connection(config.target_host, config.target_port),
            timeout=UPSTREAM_CONNECT_TIMEOUT_SECONDS,
        )
    except Exception:
        with suppress(Exception):
            await _respond(writer, "502 Bad Gateway")
        writer.close()
        with suppress(Exception):
            await writer.wait_closed()
        return

    try:
        writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        await writer.drain()
        await _tunnel(reader, writer, upstream_reader, upstream_writer)
    except (ConnectionError, asyncio.TimeoutError):
        pass
    finally:
        upstream_writer.close()
        writer.close()
        with suppress(Exception):
            await upstream_writer.wait_closed()
        with suppress(Exception):
            await writer.wait_closed()


async def _main(config: Config) -> None:
    server = await asyncio.start_server(
        lambda reader, writer: _handle(reader, writer, config),
        host=config.listen_host,
        port=config.listen_port,
        family=2,
        limit=MAX_HEADER_BYTES,
    )
    sockets = server.sockets or []
    if len(sockets) != 1:
        server.close()
        await server.wait_closed()
        raise RuntimeError("relay must own exactly one listening socket")
    print(
        f"READY listen={config.listen_host}:{config.listen_port} "
        f"peer={config.allowed_peer} target={config.authority}",
        flush=True,
    )
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(_main(_args()))
