'use strict';

const os = require('os');
const multicastDns = require('multicast-dns');

const HOSTS = [
    'sonarr.samurai.local',
    'radarr.samurai.local',
    'overseerr.samurai.local',
    'plex.samurai.local',
    'immich.samurai.local',
    'sabnzbd.samurai.local'
];

const VIRTUAL_INTERFACE_PATTERN =
    /tailscale|vethernet|hyper-v|wsl|docker|vpn|zerotier|loopback/i;

function isPrivateIpv4(address) {
    const octets = address.split('.').map(Number);

    return (
        octets.length === 4 &&
        octets.every((octet) => Number.isInteger(octet) && octet >= 0 && octet <= 255) &&
        (
            octets[0] === 10 ||
            (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
            (octets[0] === 192 && octets[1] === 168)
        )
    );
}

function findLanIpv4() {
    const configuredAddress = process.env.MDNS_IPV4;
    if (configuredAddress) {
        if (!isPrivateIpv4(configuredAddress)) {
            throw new Error(`MDNS_IPV4 is not a private IPv4 address: ${configuredAddress}`);
        }
        return { address: configuredAddress, interfaceName: 'MDNS_IPV4 override' };
    }

    const candidates = [];

    for (const [interfaceName, addresses] of Object.entries(os.networkInterfaces())) {
        if (VIRTUAL_INTERFACE_PATTERN.test(interfaceName)) {
            continue;
        }

        for (const address of addresses || []) {
            if (
                !address.internal &&
                address.family === 'IPv4' &&
                isPrivateIpv4(address.address)
            ) {
                let score = 0;
                if (/ethernet|wi-?fi|wireless|wlan/i.test(interfaceName)) score += 20;
                if (address.address.startsWith('192.168.')) score += 10;
                if (address.address.startsWith('10.')) score += 5;

                candidates.push({
                    address: address.address,
                    interfaceName,
                    score
                });
            }
        }
    }

    candidates.sort((left, right) => right.score - left.score);

    if (candidates.length === 0) {
        throw new Error(
            'No physical private IPv4 interface found. Set MDNS_IPV4 to the LAN address.'
        );
    }

    return candidates[0];
}

const lan = findLanIpv4();
const hostLookup = new Map(HOSTS.map((host) => [host.toLowerCase(), host]));
const mdns = multicastDns({ interface: lan.address });

function makeRecord(host) {
    return {
        name: host,
        type: 'A',
        class: 'IN',
        ttl: 120,
        flush: true,
        data: lan.address
    };
}

function sendResponse(answers) {
    if (answers.length === 0) return;

    mdns.respond({ answers }, (error) => {
        if (error) {
            console.error(`Failed to send mDNS response: ${error.message}`);
        }
    });
}

function announceHosts() {
    sendResponse(HOSTS.map(makeRecord));
}

mdns.on('query', (query) => {
    const requestedHosts = new Set();

    for (const question of query.questions || []) {
        if (question.type !== 'A' && question.type !== 'ANY') continue;

        const normalizedName = question.name.replace(/\.$/, '').toLowerCase();
        const canonicalName = hostLookup.get(normalizedName);
        if (canonicalName) requestedHosts.add(canonicalName);
    }

    sendResponse([...requestedHosts].map(makeRecord));
});

mdns.on('ready', () => {
    console.log(`mDNS responder bound to ${lan.interfaceName} (${lan.address})`);
    for (const host of HOSTS) {
        console.log(`  ${host} -> ${lan.address}`);
    }

    announceHosts();
    setTimeout(announceHosts, 1000);
});

mdns.on('error', (error) => {
    console.error(`mDNS responder error: ${error.message}`);
    process.exitCode = 1;
});

const announcementTimer = setInterval(announceHosts, 60_000);

function shutdown() {
    clearInterval(announcementTimer);
    mdns.destroy(() => process.exit());
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
