module permission_calculate(
  input [3:0]i_domin,
  input [31:0] i_reg3,
  input [1:0] i_ap,
  input i_apx,
  input i_ifmanager,
  output o_write,   //permission
  output o_read,
  output [1:0] o_domain_ctrl
  );
wire [1:0]domin_ctrl;
assign o_domain_ctrl=domin_ctrl;
assign domin_ctrl=(i_domin==0)?i_reg3[1:0]:
                  (i_domin==1)?i_reg3[3:2]:
                  (i_domin==2)?i_reg3[5:4]:
                  (i_domin==3)?i_reg3[7:6]:
                  (i_domin==4)?i_reg3[9:8]:
                  (i_domin==5)?i_reg3[11:10]:
                  (i_domin==6)?i_reg3[13:12]:
                  (i_domin==7)?i_reg3[15:14]:
                  (i_domin==8)?i_reg3[17:16]:
                  (i_domin==9)?i_reg3[19:18]:
                  (i_domin==10)?i_reg3[21:20]:
                  (i_domin==11)?i_reg3[23:22]:
                  (i_domin==12)?i_reg3[25:24]:
                  (i_domin==13)?i_reg3[27:26]:
                  (i_domin==14)?i_reg3[29:28]:
                  (i_domin==15)?i_reg3[31:30]:0;
assign o_write=(domin_ctrl==2'b11 || 
                  (domin_ctrl==2'b01 && 
                    (
                       (i_ifmanager==1 && i_apx==0 &&i_ap!=2'b00)||
                       (i_ifmanager==0 && i_apx==0 &&i_ap==2'b11)
                     )
                  )
                )?1:0;
assign o_read=(domin_ctrl==2'b11 || 
                (domin_ctrl==2'b01 && 
                  (
                     (i_ifmanager==1 &&
                        (i_apx==0 && i_ap!=2'b00)||
                        (i_apx==1 && (i_ap==2'b01 ||i_ap==2'b10))
                     ) ||
                     (i_ifmanager==0 &&
                        (i_apx==1 && i_ap==2'b10)||
                        (i_apx==0 && (i_ap==2'b10 ||i_ap==2'b11))
                     )
                  )
                )
              )?1:0;
endmodule