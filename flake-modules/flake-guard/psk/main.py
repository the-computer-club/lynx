#!/usr/bin/env python3
# python311Packages.fire
import json
import sys
import os
import base64

def load_previous_keys(networks, root):
    for root, dirs, files in os.walkdir(root):
        for fp in files:
            xs = os.path.join(root, fp)
            with open(xs, 'r') as fd:
                proc = Popen(['sops', 'decrypt'], stdout=PIPE, stderr=PIPE, shell=True) \
                    .communicate(input=fd.read())

                decrypted = proc.stdout.read()
                psk = json.loads(decrypted)
                network, host = fp.split(".")[0].split("-")
                networks[network]['peers']['by-name'][host] = psk

def main(root="wireguard-psk", rekey=False):
    networks = json.load(sys.stdin)

    if not rekey:
        if os.path.exists(root):
            load_previous_keys(root)
    else:
        os.rmtree(root)

    for network_name, network in networks.items():
        netmap = dict()
        peers = network['peers']['by-name'].items()

        for host_name, host_data in peers:
            for peer_name, peer_data in peers:
                if peer_name == host_name:
                    continue

                if (host_name, peer_name) in netmap or (peer_name, host_name) in netmap:
                    continue

                key = base64.b64encode(os.urandom(32)).decode('utf-8')
                netmap[(host_name, peer_name)] = key
                netmap[(peer_name, host_name)] = key

        for (host1, host2), k in netmap.items():
            if not 'psk' in network['peers']['by-name'][host1]:
                network['peers']['by-name'][host1]['psk'] = {}

            network['peers']['by-name'][host1]['psk'][host2] = k

    directory = os.path.Path(root).join(network_name)
    os.makedirs(directory, exist_ok=True)

    for network_name, network in networks.items():
        for host_name, host_data in network['peers']['by-name'].items():
            with open(os.path.join(directory, f"{network_name}-{host_name}.json"), 'w') as fd:
                Popen(['sops', 'encrypt'], stdout=fd, stderr=PIPE, shell=True) \
                    .communicate(input=json.dumps(host_data).encode('utf-8'))

if __name__ == '__main__':
    main()
