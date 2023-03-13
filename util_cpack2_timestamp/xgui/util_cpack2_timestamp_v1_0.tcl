# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"


}


proc update_MODELPARAM_VALUE.STATE_RESET { MODELPARAM_VALUE.STATE_RESET } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_RESET". Setting updated value from the model parameter.
set_property value 0 ${MODELPARAM_VALUE.STATE_RESET}
}

proc update_MODELPARAM_VALUE.STATE_WAIT_FOR_DATA { MODELPARAM_VALUE.STATE_WAIT_FOR_DATA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_WAIT_FOR_DATA". Setting updated value from the model parameter.
set_property value 1 ${MODELPARAM_VALUE.STATE_WAIT_FOR_DATA}
}

proc update_MODELPARAM_VALUE.STATE_TIMESTAMP_HEADER { MODELPARAM_VALUE.STATE_TIMESTAMP_HEADER } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_TIMESTAMP_HEADER". Setting updated value from the model parameter.
set_property value 3 ${MODELPARAM_VALUE.STATE_TIMESTAMP_HEADER}
}

proc update_MODELPARAM_VALUE.STATE_TIMESTAMP_VALUE { MODELPARAM_VALUE.STATE_TIMESTAMP_VALUE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_TIMESTAMP_VALUE". Setting updated value from the model parameter.
set_property value 4 ${MODELPARAM_VALUE.STATE_TIMESTAMP_VALUE}
}

proc update_MODELPARAM_VALUE.STATE_STORE_DATA { MODELPARAM_VALUE.STATE_STORE_DATA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_STORE_DATA". Setting updated value from the model parameter.
set_property value 5 ${MODELPARAM_VALUE.STATE_STORE_DATA}
}

proc update_MODELPARAM_VALUE.STATE_OUTPUT_DATA { MODELPARAM_VALUE.STATE_OUTPUT_DATA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_OUTPUT_DATA". Setting updated value from the model parameter.
set_property value 6 ${MODELPARAM_VALUE.STATE_OUTPUT_DATA}
}

proc update_MODELPARAM_VALUE.STATE_MAX { MODELPARAM_VALUE.STATE_MAX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_MAX". Setting updated value from the model parameter.
set_property value 7 ${MODELPARAM_VALUE.STATE_MAX}
}

proc update_MODELPARAM_VALUE.STATE_READ_DATA { MODELPARAM_VALUE.STATE_READ_DATA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	# WARNING: There is no corresponding user parameter named "STATE_READ_DATA". Setting updated value from the model parameter.
set_property value 2 ${MODELPARAM_VALUE.STATE_READ_DATA}
}

