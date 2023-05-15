# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  ipgui::add_param $IPINST -name "NUM_OF_CHANNELS"
  ipgui::add_param $IPINST -name "SAMPLES_PER_CHANNEL"
  ipgui::add_param $IPINST -name "SAMPLE_DATA_WIDTH"
  ipgui::add_param $IPINST -name "TIMESTAMP_LIMIT_EVERY_MULTIPLE"

}

proc update_PARAM_VALUE.NUM_OF_CHANNELS { PARAM_VALUE.NUM_OF_CHANNELS } {
	# Procedure called to update NUM_OF_CHANNELS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_OF_CHANNELS { PARAM_VALUE.NUM_OF_CHANNELS } {
	# Procedure called to validate NUM_OF_CHANNELS
	return true
}

proc update_PARAM_VALUE.SAMPLES_PER_CHANNEL { PARAM_VALUE.SAMPLES_PER_CHANNEL } {
	# Procedure called to update SAMPLES_PER_CHANNEL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SAMPLES_PER_CHANNEL { PARAM_VALUE.SAMPLES_PER_CHANNEL } {
	# Procedure called to validate SAMPLES_PER_CHANNEL
	return true
}

proc update_PARAM_VALUE.SAMPLE_DATA_WIDTH { PARAM_VALUE.SAMPLE_DATA_WIDTH } {
	# Procedure called to update SAMPLE_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SAMPLE_DATA_WIDTH { PARAM_VALUE.SAMPLE_DATA_WIDTH } {
	# Procedure called to validate SAMPLE_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE { PARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE } {
	# Procedure called to update TIMESTAMP_LIMIT_EVERY_MULTIPLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE { PARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE } {
	# Procedure called to validate TIMESTAMP_LIMIT_EVERY_MULTIPLE
	return true
}


proc update_MODELPARAM_VALUE.NUM_OF_CHANNELS { MODELPARAM_VALUE.NUM_OF_CHANNELS PARAM_VALUE.NUM_OF_CHANNELS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_OF_CHANNELS}] ${MODELPARAM_VALUE.NUM_OF_CHANNELS}
}

proc update_MODELPARAM_VALUE.SAMPLES_PER_CHANNEL { MODELPARAM_VALUE.SAMPLES_PER_CHANNEL PARAM_VALUE.SAMPLES_PER_CHANNEL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SAMPLES_PER_CHANNEL}] ${MODELPARAM_VALUE.SAMPLES_PER_CHANNEL}
}

proc update_MODELPARAM_VALUE.SAMPLE_DATA_WIDTH { MODELPARAM_VALUE.SAMPLE_DATA_WIDTH PARAM_VALUE.SAMPLE_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SAMPLE_DATA_WIDTH}] ${MODELPARAM_VALUE.SAMPLE_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE { MODELPARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE PARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE}] ${MODELPARAM_VALUE.TIMESTAMP_LIMIT_EVERY_MULTIPLE}
}

