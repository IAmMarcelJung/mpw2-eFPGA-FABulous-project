//Warning: The primitive InPass4_frame_config_mux was added by FABulous automatically.
(* blackbox, keep *)
module InPass4_frame_config_mux #(parameter [3:0]O_reg = 0) (
    (* iopad_external_pin *)
    output O0,
    (* iopad_external_pin *)
    output O1,
    (* iopad_external_pin *)
    output O2,
    (* iopad_external_pin *)
    output O3,
    input CLK
);
endmodule

//Warning: The primitive OutPass4_frame_config_mux was added by FABulous automatically.
(* blackbox, keep *)
module OutPass4_frame_config_mux #(parameter [3:0]I_reg = 0)(
    (* iopad_external_pin *)
    input I0,
    (* iopad_external_pin *)
    input I1,
    (* iopad_external_pin *)
    input I2,
    (* iopad_external_pin *)
    input I3,
    input CLK
);
endmodule
