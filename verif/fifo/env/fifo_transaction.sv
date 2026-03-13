`timescale 1ns/1ps

typedef enum { WRITE, READ, READ_WRITE } fifo_op_t;

class fifo_transaction extends uvm_sequence_item;
    `uvm_object_utils(fifo_transaction)

    rand fifo_op_t op;
    rand byte      data;
         byte      rd_data;

    function new(string name = "fifo_transaction");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("OP: %s | WR_DATA: 0x%h | RD_DATA: 0x%h", op.name(), data, rd_data);
    endfunction

endclass
