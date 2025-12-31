# Differential Filter on Memory — VHDL

University project developed in VHDL for the design of a memory-mapped digital system.
The module reads a sequence of signed bytes from memory, applies a differential filter,
and writes the filtered output back to memory using a finite state machine (FSM).

---

## Project Overview

The system implements a discrete, clock-driven hardware module that interfaces with
a single-port memory. Given a base address, it reads configuration data and an input
sequence, computes a filtered version of the sequence, and stores the result in memory.

The design focuses on:
- correct memory interfacing
- FSM-based control logic
- signed arithmetic and saturation
- compliance with a strict communication protocol

---

## Main Features

- **Memory-Mapped Interface**
  - Sequential read/write access to external memory
  - Address generation managed internally by the FSM

- **Finite State Machine**
  - Controls memory access, data loading, computation, and write-back
  - Handles start, reset, and completion signaling (`i_start`, `o_done`)

- **Differential Filtering**
  - Supports two filter configurations (order 3 or order 5)
  - Filter selection controlled by a configuration bit read from memory

- **Normalization and Saturation**
  - Output values normalized using shift-based approximations
  - Saturation to signed 8-bit range (−128 to +127)

---

## Architecture

The design is structured around:
- a **control path** (FSM) managing the operational phases
- a **data path** handling:
  - sliding window of input samples
  - coefficient loading
  - multiply–accumulate computation
  - normalization and saturation

Signed arithmetic is implemented using `numeric_std`.

---

## Interface

Top-level entity:

```vhdl
entity project_reti_logiche is
 port (
  i_clk      : in  std_logic;
  i_rst      : in  std_logic;
  i_start    : in  std_logic;
  i_add      : in  std_logic_vector(15 downto 0);

  o_done     : out std_logic;

  o_mem_addr : out std_logic_vector(15 downto 0);
  i_mem_data : in  std_logic_vector(7 downto 0);
  o_mem_data : out std_logic_vector(7 downto 0);
  o_mem_we   : out std_logic;
  o_mem_en   : out std_logic
 );
end project_reti_logiche;
