# Systolic Array Accelerator with Processing Element Grid and Controller

## Overview

This project implements a **systolic array-based hardware accelerator** built from a grid of **Processing Elements (PEs)** and a dedicated **controller**. The design is intended for matrix-style workloads such as **general matrix multiplication (GEMM)** and serves as a foundation for exploring hardware acceleration, custom control logic, and future CPU integration.

The core idea is to move data through a regular PE array in a pipelined manner, where each PE performs local computation and forwards intermediate values to neighboring elements. A controller coordinates the overall operation by sequencing data movement, controlling execution phases, and managing start/done behavior.

This project began as a PE and systolic array implementation and is being extended toward a more complete **programmable accelerator architecture**.

---

## Project Goals

The main goals of this project are:

- Design and implement a reusable **Processing Element (PE)**
- Build a **2D systolic array grid** from multiple PEs
- Add a **controller** to orchestrate computation and data movement
- Demonstrate end-to-end execution of matrix operations
- Provide a foundation for:
  - custom accelerator instruction/control formats
  - software-visible interfaces
  - buffer-based data movement
  - host CPU integration

---

## Why a Systolic Array?

Systolic arrays are a popular architecture for workloads with regular dataflow patterns, especially:

- matrix multiplication
- convolution
- linear algebra kernels
- machine learning inference/training primitives

They are attractive because they offer:

- high data reuse
- regular structure
- scalable parallelism
- local communication between PEs
- efficient mapping for multiply-accumulate-heavy workloads

Instead of moving all data back and forth to a centralized compute unit, data flows rhythmically through the array while computation happens in-place inside the grid.

---

## Architecture Summary

This project currently consists of two major parts:

1. **Processing Element (PE)**
2. **Systolic Array + Controller**

At a high level, the system works as follows:

- input values are fed into the array
- the controller sequences the execution
- each PE performs multiply-accumulate style computation
- data propagates through rows/columns over time
- results are accumulated and eventually collected as output
