# AXIS 1553
### AXIS interface to and from the MIL-STD-1553 bus.
---

![image](docs/manual/img/AFRL.png)

---

  author: Jay Convertino   
  
  date: 2025.06.25  
  
  details: Send and Receive MIL-STD-1553 data.   
  
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

  - [axis_1553.pdf](docs/manual/axis_1553.pdf)
  - [github page](https://johnathan-convertino-afrl.github.io/axis_1553/)

### PARAMETERS

 *   CLOCK_SPEED      - This is the aclk frequency in Hz
 *   RX_BAUD_DELAY    - Delay in rx baud enable. This will delay when we sample a bit (default is midpoint when rx delay is 0).
 *   TX_BAUD_DELAY    - Delay in tx baud enable. This will delay the time the bit output starts.

### COMPONENTS
#### SRC

* axis_1553.v
  
#### TB

* tb_cocotb.py
* tb_cocotb.v
  
### FUSESOC

* fusesoc_info.core created.
* Simulation uses icarus with cocotb

#### Targets

* RUN WITH: (fusesoc run --target=sim VENDER:CORE:NAME:VERSION)
  - default
  - lint
  - sim_cocotb
