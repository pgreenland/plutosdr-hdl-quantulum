# Additional PlutoSDR HDL Libraries

This repository contains additional IP modules for PlutoSDR.

* util_cpack2_timestamp - Implements a sample timestamping mechanism for the receive path. When integrated into the PlutoSDR HDL product between the original cpack module and DMA controller the module allows timestamps to be optionally appended at the start of sample blocks.

* util_upack2_timestamp - Implements a sample timestamping mechanism for the transmit path. When integrated into the PlutoSDR HDL product between the original DMA controller and upack module the module allows timestamps to be optionally read from the start of sample blocks. The timestamps will be used to hold samples until the transmission time is reached.

For more information see: [Private LTE with ADALM-PLUTO](https://www.quantulum.co.uk/blog/private-lte-with-analog-adalm-pluto/).
