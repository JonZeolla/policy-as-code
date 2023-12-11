#!/usr/bin/env python3
"""
Ensure the provided IP is valid and not an AWS Cloud9 IP
"""

import ipaddress
import json
import os
import sys
from ipaddress import ip_address, ip_network

import requests


def is_valid_ip(*, ip: str) -> bool:
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False


def is_private_ip(*, ip: str) -> bool:
    ip_to_check = ip_address(ip)

    if ip_to_check.is_private:
        return True
    else:
        return False


def is_aws_cloud9_ip(*, ip: str) -> bool:
    response = requests.get("https://ip-ranges.amazonaws.com/ip-ranges.json")
    aws_ips = json.loads(response.text)

    ip_to_check = ip_address(ip)

    for prefix in aws_ips["prefixes"]:
        if prefix["service"] == "CLOUD9" and ip_to_check in ip_network(
            prefix["ip_prefix"]
        ):
            return True

    for ipv6_prefix in aws_ips["ipv6_prefixes"]:
        if ipv6_prefix["service"] == "CLOUD9" and ip_to_check in ip_network(
            ipv6_prefix["ipv6_prefix"]
        ):
            return True

    return False


if __name__ == "__main__":
    ip = os.environ.get("CLIENT_IP")

    if not ip:
        sys.exit(3)
    elif not is_valid_ip(ip=ip):
        sys.exit(4)
    elif is_private_ip(ip=ip):
        sys.exit(5)
    elif is_aws_cloud9_ip(ip=ip):
        sys.exit(6)
