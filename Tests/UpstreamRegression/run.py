#!/usr/bin/env python3
"""Run production Vault and WebKit regressions on macOS, with synthetic data."""
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[2]
build = root / "build" / "upstream-regression"
build.mkdir(parents=True, exist_ok=True)
for name, sources in [
    ("vault", ["Sources/Vault.swift", "Tests/UpstreamRegression/main.swift"]),
    ("web", ["Sources/Forms.swift", "Sources/Shield.swift", "Tests/UpstreamRegression/WebHarness.swift"]),
]:
    binary = build / name
    subprocess.run(["swiftc", *sources, "-o", str(binary)], cwd=root, check=True, timeout=120)
    subprocess.run([str(binary)], cwd=root, check=True, timeout=60)
