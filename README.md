# PortonianPush
# Hybrid Infrastructure‑Assisted MANET for Industrial Emergency Resilience

## Module
**F20MX – Mobile Communications and Programming (GA)**  
Question 2 – Option 4: MANET Application Development

## Student
Susan Binnie

---

## Project Overview

This repository contains the source code and supporting materials for a mobile application proof‑of‑concept designed to improve emergency alert delivery during industrial incidents.

The application implements a **hybrid communication model**:
- **Primary channel:** Cloud-based push notifications (internet available)
- **Failsafe channel:** A **Mobile Ad‑Hoc Network (MANET)** using peer‑to‑peer communication (Bluetooth Low Energy / Wi‑Fi Direct)

If cellular or internet connectivity is unavailable, alerts are propagated **device‑to‑device** across nearby nodes, ensuring continued message delivery in network congestion, infrastructure failure, or coverage “dead zones”.

---

## Problem Context

During major industrial incidents (e.g. at Grangemouth), mobile networks can become overloaded or unavailable. Traditional alerting mechanisms rely heavily on centralised infrastructure, creating a single point of failure.

This project explores how **mobile devices themselves** can form a resilient, decentralised communication layer to support emergency messaging when infrastructure cannot be relied upon.

---

## Objectives

The key objectives of this project are:

- Develop a **cross‑platform mobile application** capable of operating in both online and offline conditions.
- Establish **peer‑to‑peer connectivity** between nearby devices without fixed infrastructure.
- Demonstrate **multi‑hop message propagation** across a minimum of three mobile nodes.
- Implement **basic security controls** to prevent unauthorised or spoofed alerts.
- Evaluate performance under different network conditions and node availability.

---

## Technical Approach

### Platform & Tools

- **Framework:** Flutter (cross‑platform mobile development)
- **Peer‑to‑Peer Communication:** Bluetooth Low Energy (BLE) and / or Wi‑Fi Direct via third‑party SDK
- **Target Devices:** Android mobile devices (physical devices used for testing)

### Architecture Summary
- Devices continuously monitor both internet connectivity and nearby peers.
- When internet connectivity is lost, the application automatically switches to **MANET mode**.
- Alerts are forwarded between trusted peers using a store‑and‑forward approach.
- Basic trust validation ensures only authorised alerts are rebroadcast.

---

## Core Features

- Nearby device discovery
- Peer‑to‑peer alert transmission
- Multi‑hop message forwarding
- Automatic failover from cloud to MANET
- Simple trust / verification mechanism
- Logging of message propagation events

---

## Evaluation & Testing

The application will be tested using multiple physical devices under different conditions, including:

- Internet connectivity enabled and disabled
- Stationary and moving nodes (“human bridge” scenario)
- Device disconnection and re‑connection

The following performance aspects are evaluated:
- Message handshaking time
- End‑to‑end latency
- Successful delivery across multiple hops
- Network stability under node mobility

Evidence (screenshots, logs, recordings) is stored in the `/evidence` directory.

---

## Repository Structure

/src            → Application source code
/evidence       → Screenshots, logs, demo recordings
/docs           → Diagrams and supporting documentation
README.md       → Project overview and guidance

---

## How to Run the Project

> Note: This project is a proof‑of‑concept and requires physical mobile devices for meaningful MANET testing.

1. Clone the repository
2. Install Flutter dependencies
3. Deploy the app to two or more mobile devices
4. Disable internet connectivity to observe MANET behaviour
5. Trigger an alert and observe propagation across devices

---

## Limitations & Future Work

- Background execution constraints imposed by mobile operating systems
- Battery consumption trade‑offs when scanning for peers
- Limited routing intelligence in the current implementation

Future work could explore:
- More advanced MANET routing protocols
- Stronger cryptographic identity management
- Larger‑scale testing with more nodes

---

## Academic Integrity & AI Use

This repository represents my **own individual work** for the F20MX coursework.

Generative AI tools were used to support learning, planning, and high‑level structuring activities.  
All code, implementation decisions, analysis, and written content are my own.

---

## Submission Notes

This repository is submitted as part of **F20MX Question 2**.  
The repository link is included in the accompanying presentation and demonstration materials.