---
author: "Martyn van Dijke"
title: "Loudify"
date: 2023-07-09
tags: ["gnuradio", "gr-lora", "zmq"]
description: "LoRa cloudified: running a GNU Radio flowgraph in a ZMQ client, broker and worker setup."
showTableOfContents: true
aliases: ["/posts/blog/loudify/"]
---

![Loudify](/img/loudify.png)

For my graduation project I extended the LoRa GNU Radio module [gr-lora_sdr](https://github.com/martynvdijke/gr-lora_sdr) into **Loudify**: a client running a GNU Radio flowgraph, a worker doing the actual demodulation, and a broker connecting the two over ZMQ.

The project — a *Centralized Radio Access Network gateway for LoRa* — researches whether LoRa packets received by different gateways can be aggregated at a central point, letting gateways share information about the signals they receive.

## Architecture

Loudify consists of three parts:

| Part       | Role                                                          |
| ---------- | ------------------------------------------------------------- |
| **Client** | Runs the GNU Radio flowgraph and captures the samples          |
| **Broker** | Central point all clients connect to; queues the work          |
| **Worker** | Receives the samples and performs the LoRa demodulation        |

## The GNU Radio module

The signal processing lives in [gr-lora_sdr](https://github.com/martynvdijke/gr-lora_sdr), a GNU Radio out-of-tree module that can:

- Transmit LoRa packets from USRP to USRP, from a commercial LoRa transceiver to a USRP and the other way around (tested with the Adafruit Feather 32u4 RFM95)
- Produce fully end-to-end experimental performance results of a LoRa SDR receiver at low SNRs
- Handle spreading factors 7–12, coding rates 0–4, implicit and explicit header mode and payloads up to the LoRa maximum of 255 bytes
- Verify the payload CRC and explicit header checksum

## Installing

The easiest way is straight from PyPI:

```sh
pip install loudify
```

Or from source, using [flit](https://flit.pypa.io/):

```sh
git clone https://github.com/martynvdijke/loudify
cd loudify
pip install flit
flit install
```

## Links

- Source code: [github.com/martynvdijke/loudify](https://github.com/martynvdijke/loudify)
- Documentation: [loudify.readthedocs.io](https://loudify.readthedocs.io/en/latest/)
- GNU Radio module: [github.com/martynvdijke/gr-lora_sdr](https://github.com/martynvdijke/gr-lora_sdr)
