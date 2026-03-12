class soup_to_uart_seq extends uart_tx_sequence;
    `uvm_object_utils(soup_to_uart_seq)

    // Handle to the SOUP sequencer (where the packets live)
    soup_sequencer s_sqr;

    virtual task body();
        soup_transaction s_tr;
        uart_transaction u_tr;

        forever begin

            // [TODO 1: Pull a SOUP packet from the soup_sequencer]
            // Hint: Use s_sqr.get_next_item(s_tr);
            s_sqr.get_next_item(s_tr);

            `uvm_info("SOUP_LAYER", "Sending START byte: 0x33", UVM_LOW)
            send_byte(8'h33);

            // [TODO 2: Send the Command Type byte]
            // Hint: use your send_byte() helper with s_tr fields.
            `uvm_info("SOUP_LAYER", "Sending CMD Type: 0 (Data)", UVM_LOW)
            send_byte(s_tr.cmd_type);

            if (!s_tr.is_response) begin
                `uvm_info("SOUP_LAYER", "Sending Payload...", UVM_LOW)
                
                // [TODO 3: Send the Length byte]
                send_byte(s_tr.payload.size());
                
                // Send the payload array
                foreach(s_tr.payload[i]) begin
                    send_byte(s_tr.payload[i]);
                end
            end

            // [TODO 4: Send the CRC byte and the STOP byte (0xCC)]
            send_byte(8'h00);
            send_byte(8'hCC);
            
            // Finish the item on the SOUP sequencer
            s_sqr.item_done();
        end
    endtask

    // Helper task to send a byte to the UART Driver
    task send_byte(byte b);
        uart_transaction u_tr;
        u_tr = uart_transaction::type_id::create("u_tr");
        start_item(u_tr);
        u_tr.data = b;
        finish_item(u_tr);
    endtask

endclass


class soup_sanity_seq extends uvm_sequence #(soup_transaction);
    `uvm_object_utils(soup_sanity_seq)

    function new (string name = "soup_sanity_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        req = soup_transaction::type_id::create("req");
        start_item(req);

        req.cmd_type    = 8'h01;
        req.is_response = 1'b0;

        req.payload     = new[4];
        req.payload[0]  = 8'hDE;
        req.payload[1]  = 8'hAD;
        req.payload[2]  = 8'hBE;
        req.payload[3]  = 8'hEF;

        req.crc         = 8'h00;

        finish_item(req);
    endtask : body
endclass
