
module top (
    input BTN1,
    output LED1
);
    assign LED1 = !BTN1;
endmodule