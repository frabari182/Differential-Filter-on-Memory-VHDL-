# Differential Filter on Memory — VHDL

Final project developed in **VHDL** for the course **Reti Logiche** at Politecnico di Milano.
The system implements a memory-mapped digital module that reads a sequence of signed
bytes from memory, applies a differential filter, and writes the filtered output
back to memory under the control of a finite state machine (FSM).

---

## Project Overview

The design implements a synchronous hardware module that interfaces with a single-port
memory. Starting from a base address, the module reads configuration parameters and
input data, performs a differential filtering operation, and stores the resulting
sequence back into memory.

The project focuses on:
- FSM-based control logic
- correct memory interfacing
- signed arithmetic and saturation
- compliance with a fixed communication protocol

---

## Main Features

- **Memory-Mapped Interface**
  - Sequential read and write access to external memory
  - Address generation handled internally by the control logic

- **Finite State Machine**
  - Coordinates memory access, computation, and write-back phases
  - Handles reset, start, and completion signaling (`i_rst`, `i_start`, `o_done`)

- **Differential Filtering**
  - Supports two filter configurations (order 3 or order 5)
  - Filter selection determined by a configuration bit read from memory

- **Normalization and Saturation**
  - Output values normalized using shift-based approximations
  - Saturation applied to the signed 8-bit range (−128 to +127)

---

## Architecture

The system is organized into:
- a **control path**, implemented as a finite state machine
- a **data path** that includes:
  - a sliding window of input samples
  - coefficient loading
  - multiply–accumulate logic
  - normalization and saturation stages

All signed arithmetic is implemented using the `numeric_std` library.

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

## Academic Context

- **Course:** Reti Logiche  
- **Institution:** Politecnico di Milano  
- **Academic Year:** 2024/2025  
- **Final Grade:** 28/30  

---

## Authors

👥 **Andrea Roberto Benvenuti**  
Codice Persona: 10682511  

👥 **Francesco Barillari**  
Codice Persona: 10858068  

**Instructor:** Prof. William Fornaciari

