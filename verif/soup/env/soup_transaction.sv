class soup_transaction extends uvm_sequence_item;

	// define fields of this transcation
	byte 	cmd_type;
	byte 	payload[]; // this is an array of bytes!
	byte 	crc;
	bit 	is_response; // MSb ? Reponse : Data

	// register w/ uvm
	`uvm_object_utils_begin(soup_transaction)
		`uvm_field_int(cmd_type, UVM_ALL_ON)
		`uvm_field_array_int(payload, UVM_ALL_ON)
		`uvm_field_int(crc, UVM_ALL_ON)
		`uvm_field_int(is_response, UVM_ALL_ON)
	`uvm_object_utils_end

	function new (string name = "soup_transaction");
		super.new(name);
	endfunction : new

	virtual function string convert2string();
		string s;
		s = $sformatf("CMD: 0x%0H | LEN: 0x%H | RESP?: 0x%0H", cmd_type, payload.size(), is_response);
		return s;
	endfunction

endclass : soup_transaction
