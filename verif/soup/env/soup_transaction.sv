class soup_transaction extends uvm_sequence_item;
	// register w/ uvm
	`uvm_object_utils(soup_transaction)

	// define fields of this transcation
	byte 	cmd_type;
	byte 	payload[]; // this is an array of bytes!
	byte 	crc;
	bit 	is_response; // MSb ? Reponse : Data

	function new (string name = "soup_transaction");
		super.new(name);
	endfunction : new

	virtual function string convert2string();
		string s;
		s = $sformatf("CMD: 0x%0H | LEN: 0x%H | RESP?: 0x%0H", cmd_type, payload.size(), is_response);
		return s;
	endfunction

endclass : soup_transaction