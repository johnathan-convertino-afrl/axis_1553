# AXIS 1553 ENCODER
### AXIS TO MIL-STD-1553 bus.

![image](docs/manual/img/AFRL.png)

---

  author: Jay Convertino   
  
  date: 2021.05.17  
  
  details: Incoming AXI streaming data is used to populate a MIL-STD-1553 compliant signal.   
  
  license: MIT   
  
  Actions:  

  [![Lint Status](../../actions/workflows/lint.yml/badge.svg)](../../actions)  
  [![Manual Status](../../actions/workflows/manual.yml/badge.svg)](../../actions)  
  
---

### Version
#### Current
  - V1.0.0 - initial release

#### Previous
  - none

### DOCUMENTATION
  For detailed usage information, please navigate to one of the following sources. They are the same, just in a different format.

  - [axis_1553_encoder.pdf](docs/manual/axis_1553_encoder.pdf)
  - [github page](https://johnathan-convertino-afrl.github.io/axis_1553_encoder/)

### PARAMETERS

* CLOCK_SPEED : DEFAULT = 200000000 : clock speed of aclk to the core in hz.
* SAMPLE_RATE : DEFAULT = 2000000   : sample rate of generated signal in hz (minimum 2 MHz).

### COMPONENTS
#### SRC

* axis_1553_encoder.v
  
#### TB

* tb_1553_enc.v
* tb_cocotb.py
* tb_cocotb.v
  
### FUSESOC

* fusesoc_info.core created.
* Simulation uses icarus to run data through the core for a fixed amount of time, no verifcation of data in/out.

#### Targets

* RUN WITH: (fusesoc run --target=sim VENDER:CORE:NAME:VERSION)
  - default
  - lint
  - sim_cocotb
