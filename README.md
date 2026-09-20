![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# IEEE Flappy Bird VGA Game 🐤

Welcome to the Flappy Bird VGA Game project for Tiny Tapeout! 

![Flappy Bird Preview](docs/FlappyBirdPreview.png)

This repository contains a hardware-level digital design that generates a dynamic 640x480 VGA game using pure combinational Verilog logic and fixed-point arithmetic. 

Designed to fit in a standard 1x1 tile, the circuit renders dynamic physics, procedural pipe gaps, parallax cloud scrolling, and an animated floor without relying on external RAM or frame buffers.

## 📖 Project Documentation

To keep this repository clean, the detailed explanation of the hardware architecture and testing instructions have been moved to the documentation folder.

For a comprehensive breakdown of the project, including:
* How the finite state machine (FSM), fixed-point bird physics, and procedural pipe generation work.
* Step-by-step instructions for web simulation, local Cocotb testbenches, and physical hardware deployment using TinyVGA PMOD.

**Please refer to the project documentation located at [`docs/info.md`](docs/info.md).**

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)
