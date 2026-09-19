"""Loopback ENet integration tests with real UDP delay, jitter and loss.

Usage: python tests/network_conditions.py --godot PATH_TO_GODOT
Only the spawned processes and loopback sockets are managed by this script.
"""
import argparse
import heapq
import json
import pathlib
import random
import re
import socket
import subprocess
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOGS = ROOT / ".godot" / "network-conditions"
LOGS.mkdir(parents=True, exist_ok=True)


class Proxy:
    def __init__(self, listen_port, server_port, rtt):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(("127.0.0.1", listen_port))
        self.socket.settimeout(0.002)
        self.server = ("127.0.0.1", server_port)
        self.client = None
        self.rtt = rtt / 1000
        self.stop = threading.Event()
        self.random = random.Random(rtt)
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        queue = []
        serial = 0
        while not self.stop.is_set():
            try:
                data, source = self.socket.recvfrom(65535)
                if source == self.server:
                    destination = self.client
                else:
                    self.client = source
                    destination = self.server
                if destination and self.random.random() >= 0.01:
                    delay = self.rtt / 2 + self.random.uniform(-self.rtt / 10, self.rtt / 10)
                    serial += 1
                    heapq.heappush(queue, (time.monotonic() + delay, serial, data, destination))
            except (socket.timeout, ConnectionResetError):
                pass
            while queue and queue[0][0] <= time.monotonic():
                _, _, data, destination = heapq.heappop(queue)
                self.socket.sendto(data, destination)

    def close(self):
        self.stop.set()
        self.thread.join(timeout=2)
        self.socket.close()


def launch(godot, name, *args):
    log = LOGS / (name + ".log")
    log.unlink(missing_ok=True)
    if "--host" in args:
        port = next((arg.split("=")[1] for arg in args if arg.startswith("--port=")), "7000")
        for stage in ("listening", "match"):
            (ROOT / ".godot" / f"test_{port}_{stage}.ready").unlink(missing_ok=True)
    process = subprocess.Popen(
        [godot, "--headless", "--path", str(ROOT), "--max-fps", "60",
         "--quit-after", "4800", "--log-file", str(log), "--", "--report", *args],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    return process, log


def wait_log(item, marker, timeout=35):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if item[1].exists() and marker in item[1].read_text(encoding="utf-8-sig", errors="replace"):
            return
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {marker} in {item[1]}")


def wait_stage(port, stage="listening", timeout=35):
    path = ROOT / ".godot" / f"test_{port}_{stage}.ready"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for host stage: {path}")


def collect(items):
    try:
        for process, _ in items:
            process.wait(timeout=80)
        for item in items:
            wait_log(item, "TEST_REPORT", 35)
        texts = [path.read_text(encoding="utf-8-sig", errors="replace") for _, path in items]
        for text in texts:
            assert "SCRIPT ERROR" not in text, text[-3000:]
            assert "Condition " not in text, text[-3000:]
            assert "above the MTU" not in text, text[-3000:]
            assert 'Parameter "spawner" is null' not in text, text[-3000:]
            assert "unknown peer ID" not in text, text[-3000:]
            assert "Unable to send packet" not in text, text[-3000:]
        return texts
    finally:
        for process, _ in items:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)


def report(text):
    return json.loads(re.findall(r"TEST_REPORT (.+)", text)[-1])


def latency_case(godot, rtt, port):
    proxy = Proxy(port + 1, port, rtt)
    items = []
    try:
        items.append(launch(godot, f"rtt{rtt}_host", "--host", f"--port={port}", "--auto-ready",
                            "--start-after=4", "--test-duration=9", "--npcs=40",
                            "--quit-after=60", "--quit-on-result", "--name=Host", "--test-walk", "--expect-humans=2"))
        wait_stage(port)
        items.append(launch(godot, f"rtt{rtt}_client", "--join=127.0.0.1", f"--port={port + 1}",
                            "--auto-ready", "--quit-after=60", "--quit-on-result", "--name=Client", "--test-walk"))
        host, client = collect(items)
        host_result = json.loads(re.findall(r"MATCH_RESULT (.+)", host)[-1])
        client_result = json.loads(re.findall(r"MATCH_RESULT (.+)", client)[-1])
        assert host_result == client_result
        assert report(client)["snapshots"] > 0, "Client never received actor snapshots"
        assert report(client)["phase"] == "result"
        assert len(host_result) == 2
        print(f"PASS: RTT {rtt} ms + jitter + 1% UDP loss; moving players; identical results", flush=True)
    finally:
        proxy.close()
        for process, _ in items:
            if process.poll() is None:
                process.terminate()


def failure_cases(godot):
    # All cases run in independent rooms.
    items = []
    items.append(launch(godot, "version_host", "--host", "--port=17200", "--quit-after=7"))
    wait_stage(17200)
    items.append(launch(godot, "exit_host", "--host", "--port=17201", "--quit-after=4"))
    wait_stage(17201)
    items.append(launch(godot, "late_host", "--host", "--port=17202", "--auto-ready",
                        "--start-after=1", "--test-duration=20", "--npcs=0", "--quit-after=12"))
    wait_stage(17202, "match")
    items.append(launch(godot, "version_client", "--join=127.0.0.1", "--port=17200",
                        "--protocol=999", "--quit-after=5"))
    items.append(launch(godot, "exit_client", "--join=127.0.0.1", "--port=17201", "--quit-after=7"))
    time.sleep(2)
    items.append(launch(godot, "late_client", "--join=127.0.0.1", "--port=17202", "--quit-after=5"))
    texts = collect(items)
    assert "incompatível" in report(texts[3])["message"]
    assert report(texts[4])["phase"] == "menu" and "anfitrião" in report(texts[4])["message"]
    assert "já começou" in report(texts[5])["message"]
    print("PASS: incompatible protocol, host disconnect, late admission rejected", flush=True)


def capacity_case(godot):
    items = [launch(godot, "capacity_host", "--host", "--port=17210", "--quit-after=10")]
    wait_stage(17210)
    items.append(launch(godot, "occupied_host", "--host", "--port=17210", "--quit-after=4"))
    for index in range(8):
        items.append(launch(godot, f"capacity_client{index}", "--join=127.0.0.1",
                            "--port=17210", "--quit-after=12"))
        time.sleep(0.1)
    texts = collect(items)
    assert report(texts[0])["roster"] == 8
    assert "porta ocupada" in report(texts[1])["message"]
    assert any("cheia" in report(text)["message"] for text in texts[2:])
    print("PASS: 8-human cap, explicit full-room rejection, occupied port", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--failures-only", action="store_true")
    options = parser.parse_args()
    if not options.failures_only:
        for latency, port in [(50, 17100), (100, 17110), (200, 17120)]:
            latency_case(options.godot, latency, port)
    failure_cases(options.godot)
    capacity_case(options.godot)
    print(f"Logs: {LOGS}")
