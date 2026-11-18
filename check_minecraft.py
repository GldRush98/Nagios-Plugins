#!/usr/bin/env python3
# coding=utf-8
# Nagios Check Script to monitor the status of a Minicraft Java server
# Original script idea v1: https://github.com/vertecx/nagios-plugins/blob/master/check_minecraft.py
# Rewritten version v2: Nick Overstreet 11/2026
# check_minecraft.py now features:
# -Python 3 compatibility
# -Modern Minecraft Java server support (tested with v26.3)
# -Modern Minecraft protocol ping/pong response-time checking with warning and critical thresholds
# -Modern JSON MOTD responses, including formatted text components, MOTD checking now optional
# -Online and maximum player counts, Server-full warnings, as well as added performance data for logging
# -Verbose diagnostic output

import argparse
import json
import socket
import struct
import sys
import time

from datetime import datetime, timedelta

# Nagios exit statuses
STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3

# ---------------------------------------------------------
# Minecraft protocol helpers
# ---------------------------------------------------------

def encode_varint(value):
    """Encode an integer as a Minecraft VarInt."""

    value &= 0xFFFFFFFF
    result = bytearray()

    while True:
        temp = value & 0x7F
        value >>= 7

        if value:
            temp |= 0x80

        result.append(temp)

        if not value:
            break

    return bytes(result)


def decode_varint(sock):
    """Read a Minecraft VarInt from a socket."""

    result = 0
    position = 0

    while True:
        data = recv_exact(sock, 1)
        byte = data[0]

        result |= (byte & 0x7F) << position
        position += 7

        if position >= 35:
            raise ValueError("VarInt is too large")

        if not (byte & 0x80):
            break

    return result


def decode_varint_from_bytes(data):
    """Decode a VarInt from a byte sequence."""

    result = 0
    position = 0

    for byte in data:

        result |= (byte & 0x7F) << position
        position += 7

        if position >= 35:
            raise ValueError("VarInt is too large")

        if not (byte & 0x80):
            return result

    raise ValueError("Incomplete VarInt")


def recv_exact(sock, length):
    """Receive exactly the requested number of bytes."""

    data = bytearray()

    while len(data) < length:

        chunk = sock.recv(length - len(data))

        if not chunk:
            raise ConnectionError("Connection closed by server")

        data.extend(chunk)

    return bytes(data)


def encode_string(value):
    """Encode a Minecraft protocol string."""

    data = value.encode("utf-8")

    return encode_varint(len(data)) + data


def make_packet(data):
    """Add Minecraft packet length prefix."""

    return encode_varint(len(data)) + data


def extract_text(component):
    """Extract readable text from Minecraft JSON components."""

    if isinstance(component, str):
        return component

    if isinstance(component, list):
        return "".join(extract_text(item) for item in component)

    if isinstance(component, dict):

        result = component.get("text", "")

        if "translate" in component and not result:
            result = component["translate"]

        if "with" in component:
            result += "".join(
                extract_text(item) for item in component["with"]
            )

        if "extra" in component:
            result += "".join(
                extract_text(item) for item in component["extra"]
            )

        return result

    return ""


def log(start, message):

    print("{0}: {1}".format(
        datetime.now() - start,
        message
    ))


# ---------------------------------------------------------
# Minecraft server status and ping
# ---------------------------------------------------------

def get_server_info(host, port, num_checks, timeout, verbose):

    start_time = datetime.now()

    total_ping_delta = 0.0
    total_status_delta = 0.0
    byte_count = 0

    status = None

    for i in range(num_checks):

        iteration = "Iteration {0}/{1}: ".format(
            i + 1, num_checks
        )

        if verbose:
            log(
                start_time,
                "{0}Connecting to {1} on port {2}.".format(
                    iteration, host, port
                )
            )

        with socket.create_connection(
            (host, port), timeout=timeout
        ) as s:

            s.settimeout(timeout)

            # -------------------------------------------------
            # Handshake packet
            # -------------------------------------------------

            if verbose:
                log(start_time, "{0}Sending handshake.".format(iteration))

            handshake = (
                encode_varint(0)       # Packet ID
                + encode_varint(0)     # Protocol version (status only)
                + encode_string(host)  # Server address
                + port.to_bytes(2, "big")
                + encode_varint(1)     # Next state: Status
            )

            packet = make_packet(handshake)

            s.sendall(packet)
            byte_count += len(packet)

            # -------------------------------------------------
            # Status request packet
            # -------------------------------------------------

            if verbose:
                log(
                    start_time,
                    "{0}Sending Server Status Request.".format(iteration)
                )

            packet = make_packet(encode_varint(0))

            s.sendall(packet)
            byte_count += len(packet)

            # -------------------------------------------------
            # Receive status response
            # -------------------------------------------------

            if verbose:
                log(
                    start_time,
                    "{0}Receiving server status.".format(iteration)
                )

            packet_length = decode_varint(s)

            if packet_length <= 0 or packet_length > 1048576:
                raise ValueError("Invalid response packet length")

            response = recv_exact(s, packet_length)
            byte_count += packet_length

            packet_id = decode_varint_from_bytes(response)

            if packet_id != 0:
                raise ValueError(
                    "Unexpected server response packet ID"
                )

            # Skip packet ID
            offset = len(encode_varint(packet_id))

            # Read JSON string length
            json_length = decode_varint_from_bytes(response[offset:])

            length_offset = len(encode_varint(json_length))

            offset += length_offset

            json_data = response[offset:offset + json_length]

            if len(json_data) != json_length:
                raise ValueError("Incomplete JSON response")

            status = json.loads(json_data.decode("utf-8"))

            status_delta = 0.0

            if verbose:
                log(
                    start_time,
                    "{0}Received valid server status.".format(iteration)
                )

            # -------------------------------------------------
            # Minecraft Ping / Pong
            # -------------------------------------------------

            if verbose:
                log(
                    start_time,
                    "{0}Sending Ping Request.".format(iteration)
                )

            # Generate timestamp in milliseconds
            ping_token = int(time.time() * 1000)

            # Packet ID 0x01 + signed 64-bit timestamp
            ping_data = (
                encode_varint(1)
                + struct.pack(">q", ping_token)
            )

            ping_packet = make_packet(ping_data)

            # Start ping measurement
            ping_start = time.perf_counter()

            s.sendall(ping_packet)
            byte_count += len(ping_packet)

            if verbose:
                log(
                    start_time,
                    "{0}Waiting for Pong Response.".format(iteration)
                )

            # Receive Pong packet
            pong_length = decode_varint(s)

            if pong_length != 9:
                raise ValueError(
                    "Invalid Pong packet length: {0}".format(pong_length)
                )

            pong_response = recv_exact(s, pong_length)
            byte_count += pong_length

            pong_packet_id = decode_varint_from_bytes(pong_response)

            if pong_packet_id != 1:
                raise ValueError(
                    "Unexpected Pong packet ID: {0}".format(
                        pong_packet_id
                    )
                )

            pong_token = struct.unpack(
                ">q",
                pong_response[len(encode_varint(pong_packet_id)):]
            )[0]

            ping_delta = time.perf_counter() - ping_start

            # Verify returned timestamp
            if pong_token != ping_token:
                raise ValueError(
                    "Pong timestamp mismatch: sent {0}, received {1}".format(
                        ping_token, pong_token
                    )
                )

            total_ping_delta += ping_delta

            if verbose:
                log(
                    start_time,
                    "{0}Received valid Pong Response: {1:.3f} ms.".format(
                        iteration,
                        ping_delta * 1000
                    )
                )

                log(
                    start_time,
                    "{0}Ping response time: {1:.3f} ms.".format(
                        iteration,
                        ping_delta * 1000
                    )
                )

            # Status retrieval time is measured separately
            # from ping/pong latency.
            total_status_delta += status_delta

        if i < num_checks - 1:
            time.sleep(0.1)

    average_response = total_ping_delta / num_checks

    average_status = total_status_delta / num_checks

    # -----------------------------------------------------
    # Extract server information
    # -----------------------------------------------------

    motd = extract_text(status.get("description", ""))

    players = status.get("players", {})

    online = players.get("online", 0)
    maximum = players.get("max", 0)

    version = status.get("version", {}).get("name", "Unknown")

    return {
        "motd": motd,
        "players": online,
        "max_players": maximum,
        "version": version,
        "byte_count": byte_count,
        "response_time": average_response,
        "status_time": average_status
    }


# ---------------------------------------------------------
# Nagios output
# ---------------------------------------------------------

def format_output(state, message, info, warning, critical):

    templates = {
        STATE_OK: "MINECRAFT OK",
        STATE_WARNING: "MINECRAFT WARNING",
        STATE_CRITICAL: "MINECRAFT CRITICAL",
        STATE_UNKNOWN: "MINECRAFT UNKNOWN"
    }

    prefix = templates.get(state, "MINECRAFT UNKNOWN")

    return (
    "{0}: {1} - {2} bytes, "
    "Ping: {3:.3f}s, Status: {4:.3f}s"
    "|ping={3}s;{5};{6};0; "
    "status={4}s;;;; "
    "players_online={7};;;; "
    "players_max={8};;;;"
    ).format(
        prefix,
        message,
        info["byte_count"],
        info["response_time"],
        info["status_time"],
        warning,
        critical,
        info["players"],
        info["max_players"]
    )


# ---------------------------------------------------------
# Main Nagios plugin
# ---------------------------------------------------------

def main():

    parser = argparse.ArgumentParser(
        description="Nagios plugin for Minecraft Java Edition servers."
    )

    parser.add_argument(
        "-H", "--hostname",
        dest="hostname",
        metavar="ADDRESS",
        required=True,
        help="host name or IP address"
    )

    parser.add_argument(
        "-p", "--port",
        dest="port",
        type=int,
        default=25565,
        metavar="INTEGER",
        help="port number (default: 25565)"
    )

    parser.add_argument(
        "-n", "--number-of-checks",
        dest="num_checks",
        type=int,
        default=5,
        metavar="INTEGER",
        help="number of checks (default: 5)"
    )

    parser.add_argument(
        "-m", "--motd",
        dest="motd",
        default=None,
        metavar="STRING",
        help="expected MOTD (optional)"
    )

    parser.add_argument(
        "-f", "--warn-on-full",
        dest="full",
        action="store_true",
        help="generate warning if server is full"
    )

    parser.add_argument(
        "-w", "--warning",
        dest="warning",
        type=float,
        default=0.0,
        metavar="DOUBLE",
        help="ping response time warning threshold in seconds"
    )

    parser.add_argument(
        "-c", "--critical",
        dest="critical",
        type=float,
        default=0.0,
        metavar="DOUBLE",
        help="ping response time critical threshold in seconds"
    )

    parser.add_argument(
        "-t", "--timeout",
        dest="timeout",
        type=float,
        default=10.0,
        metavar="DOUBLE",
        help="connection timeout (default: 10)"
    )

    parser.add_argument(
        "-v", "--verbose",
        dest="verbose",
        action="store_true",
        help="show debugging information"
    )

    args = parser.parse_args()

    if (
        args.port < 1 or args.port > 65535
        or args.num_checks < 1
        or args.timeout <= 0
        or args.warning < 0
        or args.critical < 0
        or (
            args.warning > 0
            and args.critical > 0
            and args.warning > args.critical
        )
    ):

        print("MINECRAFT UNKNOWN: Invalid arguments")
        sys.exit(STATE_UNKNOWN)

    try:

        info = get_server_info(
            args.hostname,
            args.port,
            args.num_checks,
            args.timeout,
            args.verbose
        )

        if args.verbose:

            print("Minecraft version: {0}".format(info["version"]))
            print("MOTD: {0}".format(info["motd"]))

            print(
                "Players: {0}/{1}".format(
                    info["players"],
                    info["max_players"]
                )
            )

            print(
                "Average ping: {0:.3f} ms".format(
                    info["response_time"] * 1000
                )
            )

        # -------------------------------------------------
        # Check MOTD
        # -------------------------------------------------

        if args.motd is not None and args.motd not in info["motd"]:

            print(
                format_output(
                    STATE_WARNING,
                    "Unexpected MOTD: {0}".format(info["motd"]),
                    info,
                    args.warning,
                    args.critical
                )
            )

            sys.exit(STATE_WARNING)

        # -------------------------------------------------
        # Critical response time
        # -------------------------------------------------

        if (
            args.critical
            and info["response_time"] > args.critical
        ):

            print(
                format_output(
                    STATE_CRITICAL,
                    "Ping response time exceeded critical threshold",
                    info,
                    args.warning,
                    args.critical
                )
            )

            sys.exit(STATE_CRITICAL)

        # -------------------------------------------------
        # Warning response time
        # -------------------------------------------------

        if (
            args.warning
            and info["response_time"] > args.warning
        ):

            print(
                format_output(
                    STATE_WARNING,
                    "Ping response time exceeded warning threshold",
                    info,
                    args.warning,
                    args.critical
                )
            )

            sys.exit(STATE_WARNING)

        # -------------------------------------------------
        # Check if server is full
        # -------------------------------------------------

        if (
            args.full
            and info["players"] >= info["max_players"]
        ):

            print(
                format_output(
                    STATE_WARNING,
                    "Server full! {0} players online".format(
                        info["players"]
                    ),
                    info,
                    args.warning,
                    args.critical
                )
            )

            sys.exit(STATE_WARNING)

        # -------------------------------------------------
        # Everything OK
        # -------------------------------------------------

        print(
            format_output(
                STATE_OK,
                "{0}/{1} players online".format(
                    info["players"],
                    info["max_players"]
                ),
                info,
                args.warning,
                args.critical
            )
        )

        sys.exit(STATE_OK)

    except (OSError, ValueError, ConnectionError, json.JSONDecodeError) as msg:

        print("MINECRAFT CRITICAL: {0}".format(msg))
        sys.exit(STATE_CRITICAL)

    except Exception as msg:

        print("MINECRAFT UNKNOWN: {0}".format(msg))
        sys.exit(STATE_UNKNOWN)


if __name__ == "__main__":
    main()
