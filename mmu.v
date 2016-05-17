module mmu
(
  input		i_clk,
	input		i_rst,

//cache
  input [31:0] i_icache_data,  //cache data back
  input [31:0] i_dcache_data,
  input i_icache_ack,  //cache ack
  input i_dcache_ack,
  output o_read_i,   //request to cache
  output o_read_d,
  output o_write_d,  
  output [31:0] 	o_addr_i,  //phy addr to cache
  output [31:0] 	o_addr_d,
  output [31:0] o_data_cache,
  //cpu
  //MRC&MCR
  input i_cp15sel,   
  input i_cp15write,
  input [3:0] i_crn,
  input [3:0] i_crm,
  input [2:0] i_opcode1,
  input [2:0] i_opcode2,  
  input [31:0] i_cpudata,  //MCR && write cache
  output [31:0] o_cpudata,  //MRC
  //addr&data back
  input i_read_i,   //request from cpu
  input i_read_d,
  input i_write_d,   
  input i_ifmanager,
  input [31:0] 	i_addr_i,  //virtual addr from cpu
  input [31:0] 	i_addr_d,
  output [31:0] o_data_i,
  output [31:0] o_data_d,
  output o_ack_i,    //ack to cpu
  output o_ack_d,
  
  //error
  output o_error_i,
  output o_error_d
);
//tlb_i_variable
reg i_search_valid_i;
wire [31:0] o_result_addr_i;
wire [3:0] o_domin_i;
wire [1:0] i_type_i;
wire [31:12] i_pa_i;
wire [3:0] i_domin_i;
wire [7:0] i_asid_i;
wire [31:12] i_invalidate_mva_i;
wire [7:0] i_invalidate_asid_i;
wire [31:0] search_tlb_addr_i;
wire [1:0] o_ap_i;
wire [11:4] i_ap_i;
wire o_search_ack_i;
wire o_apx_i;
//tlb_d_variable
reg i_search_valid_d;
wire [31:0] o_result_addr_d;
wire [3:0] o_domin_d;
wire [1:0] i_type_d;
wire [31:12] i_pa_d;
wire [3:0] i_domin_d;
wire [7:0] i_asid_d;
wire [31:12] i_invalidate_mva_d;
wire [7:0] i_invalidate_asid_d;
wire [31:0] search_tlb_addr_d;
wire [1:0] o_ap_d;
wire [11:4] i_ap_d;
wire o_search_ack_d;
wire o_apx_d;
//permission
wire [4:0] i_domin_per_i;
wire [4:0] i_domin_per_d;
wire o_read_per_i;
wire o_read_per_d;
wire o_write_per_d;
wire [1:0] i_ap_per_i;
wire [1:0] i_ap_per_d;
//mmu_variable
wire [31:0]o_addr_i_w;
wire [31:0]o_addr_d_w;
wire o_ack_i_w;
wire o_ack_d_w;
wire o_read_i_w;
wire o_read_d_w;
wire o_write_d_w;
`define idle 0
`define search_tlb 1
`define first_level 2
`define second_level 3
`define get_data 4

reg [2:0] fsm_i;
reg [2:0] fsm_d;
reg [8:5] domin_temp_i;
reg [8:5] domin_temp_d;
reg [31:0] last_addr_i;
reg [31:0] last_addr_d;
//cp15_variable
reg [31:0] cp0_ID=32'b01000001000001111000000000000000;
reg [31:0] cp0_TLB=32'b00000000000000000000000000000001;
reg [31:0] cp0_cache=32'b00000011000101010001000101010001;
reg [31:0] cp1_control=32'b00000100000001010101000001110111;
reg [31:0] cp1_access=32'b00000000000000000000000000000000;
reg [31:0] cp2_control=32'b00000000000000000000000000000001;
reg [31:0] cp2_base0=32'b00000000000000000000000000000001;
reg [31:0] cp2_base1=32'b00000000000000100000000000000001;
reg [31:0] cp3_domain;   
reg [31:0] cp5_ins=32'd0;
reg [31:0] cp5_data=32'd0;
reg [31:0] cp6_ins=32'd0;
reg [31:0] cp6_data=32'd0;
reg [31:0] cp6_watch=32'd0;
reg [31:0] cp7_cache_management;
reg [31:0] cp8_TLB_function;
reg [31:0] cp9_cache_lockdown;
reg [31:0] cp10_TLB_lockdown;
reg [31:0] cp11_DMA;
reg [31:0] cp13_FCSE;
reg [31:0] cp13_contex;

reg [31:0] result;

//base addr
wire [31:7]cp1_baseaddr;
wire [2:0] n;
wire use_ttr0;
assign use_ttr0=(cp2_control[2:0]==0)||(cp2_control[2:0]==1 && cp2_base0[31]==0)||
(cp2_control[2:0]==2 && cp2_base0[31:30]==0)||(cp2_control[2:0]==3 && cp2_base0[31:29]==0)||
(cp2_control[2:0]==4 && cp2_base0[31:28]==0)||(cp2_control[2:0]==5 && cp2_base0[31:27]==0)||
(cp2_control[2:0]==6 && cp2_base0[31:26]==0)||(cp2_control[2:0]==7 && cp2_base0[31:25]==0);
assign n=use_ttr0?cp2_control[2:0]:0;
assign cp1_baseaddr=use_ttr0?cp2_base0[31:7]:cp2_base1[31:7];

assign o_data_cache=i_cpudata;
assign o_data_i=(cp1_control[0]&&!o_ack_i_w)?0:i_icache_data;
assign o_data_d=(cp1_control[0]&&!o_ack_d_w)?0:i_dcache_data;
assign o_addr_i=cp1_control[0]?o_addr_i_w:i_addr_i;
assign o_addr_d=cp1_control[0]?o_addr_d_w:i_addr_d;

assign o_ack_i=cp1_control[0]?o_ack_i_w:i_icache_ack;  
assign o_ack_d=cp1_control[0]?o_ack_d_w:i_dcache_ack;  
assign o_read_i=cp1_control[0]?o_read_i_w:i_read_i;  
assign o_read_d=cp1_control[0]?o_read_d_w:i_read_d;  
assign o_write_d=cp1_control[0]?o_write_d_w:i_write_d;  

assign o_ack_i_w=(fsm_i==`get_data && i_icache_ack);
assign o_ack_d_w=(fsm_d==`get_data && i_dcache_ack);
assign o_read_i_w=((fsm_i==`search_tlb && o_search_ack_i==1 && o_read_per_i==1 )||
                   (fsm_i==`search_tlb && o_search_ack_i==0)||
                   (fsm_i==`first_level && i_icache_ack && 
                     (i_icache_data[1:0]==2'b01 || 
                        (i_icache_data[1:0]==2'b10 && o_read_per_i==1 && 
                           !(i_icache_data[18]==1 && cp1_control[23]==0)
                        )
                     )
                   )||
                   (fsm_i==`first_level && !i_icache_ack)||
                   (fsm_i==`second_level && i_icache_ack && o_read_per_i &&
                     (i_icache_data[1:0]==2'b01 || 
                       (i_icache_data[1:0]==2'b10 && cp1_control[23]==0)
                     )
                   )||
                   (fsm_i==`second_level && !i_icache_ack)||
                   (fsm_i==`get_data && !i_icache_ack)
                   )?1:0;  //needs optimised
assign o_read_d_w=((fsm_d==`search_tlb && o_search_ack_d==1 && o_read_per_d==1 && i_read_d==1 )||
                   (fsm_d==`search_tlb && o_search_ack_d==0)||
                   (fsm_d==`first_level && i_dcache_ack && 
                      (i_dcache_data[1:0]==2'b01 || 
                         (i_dcache_data[1:0]==2'b10 && o_read_per_d==1 && i_read_d==1 && 
                            !(i_dcache_data[18]==1 && cp1_control[23]==0)
                         )
                      )
                   )||
                   (fsm_d==`first_level && !i_dcache_ack)||
                   (fsm_d==`second_level && i_dcache_ack && o_read_per_d && i_read_d==1 &&
                      (i_dcache_data[1:0]==2'b01 || 
                         (i_dcache_data[1:0]==2'b10 && cp1_control[23]==0)
                      )
                   )||
                   (fsm_d==`second_level && !i_dcache_ack )||
                   (fsm_d==`get_data && i_read_d==1 && !i_dcache_ack)
                   )?1:0;
assign o_write_d_w=i_write_d==1 &&( 
                     (fsm_d==`first_level && i_dcache_ack && 
                        (i_dcache_data[1:0]==2'b10 && o_write_per_d==1 && 
                           !(i_dcache_data[19]==1 && cp1_control[23]==0)
                        )
                      )||
                     (fsm_d==`second_level && i_dcache_ack && o_write_per_d && 
                        (i_dcache_data[1:0]==2'b01 || 
                           (i_dcache_data[1:0]==2'b10 && cp1_control[23]==0)
                        )
                      )||
                     (fsm_d==`get_data && !i_dcache_ack)
                    )?1:0;

assign o_addr_i_w=(fsm_i==`search_tlb && o_search_ack_i==0)?(
                          (n==1)?{cp1_baseaddr[31:13],i_addr_i[30:20],2'b00}:
                          (n==2)?{cp1_baseaddr[31:12],i_addr_i[29:20],2'b00}:
                          (n==3)?{cp1_baseaddr[31:11],i_addr_i[28:20],2'b00}:
                          (n==4)?{cp1_baseaddr[31:10],i_addr_i[27:20],2'b00}:
                          (n==5)?{cp1_baseaddr[31:9],i_addr_i[26:20],2'b00}:
                          (n==6)?{cp1_baseaddr[31:8],i_addr_i[25:20],2'b00}:
                          (n==7)?{cp1_baseaddr[31:7],i_addr_i[24:20],2'b00}:
                                 {cp1_baseaddr[31:14],i_addr_i[31:20],2'b00}):
                    (fsm_i==`search_tlb && o_search_ack_i==1 && o_read_per_i==1)?o_result_addr_i:
                    (fsm_i==`first_level && i_icache_ack && i_icache_data[1:0]==2'b01)?{i_icache_data[31:10],i_addr_i[19:12],2'b00}:
                    (fsm_i==`first_level && i_icache_ack && i_icache_data[1:0]==2'b10  && i_icache_data[19]==0)?{i_icache_data[31:20],i_addr_i[19:0]}:
                    (fsm_i==`first_level && i_icache_ack && i_icache_data[1:0]==2'b10  && i_icache_data[19]==1)?{i_icache_data[31:24],i_addr_i[23:0]}:
                    (fsm_i==`second_level && i_icache_ack && i_icache_data[1:0]==2'b01 )?{i_icache_data[31:16],i_addr_i[15:0]}:
                    (fsm_i==`second_level && i_icache_ack && i_icache_data[1:0]==2'b10 )?{i_icache_data[31:12],i_addr_i[11:0]}:last_addr_i;

assign o_addr_d_w=(fsm_d==`search_tlb && o_search_ack_d==0)?(
                          (n==1)?{cp1_baseaddr[31:13],i_addr_d[30:20],2'b00}:
                          (n==2)?{cp1_baseaddr[31:12],i_addr_d[29:20],2'b00}:
                          (n==3)?{cp1_baseaddr[31:11],i_addr_d[28:20],2'b00}:
                          (n==4)?{cp1_baseaddr[31:10],i_addr_d[27:20],2'b00}:
                          (n==5)?{cp1_baseaddr[31:9],i_addr_d[26:20],2'b00}:
                          (n==6)?{cp1_baseaddr[31:8],i_addr_d[25:20],2'b00}:
                          (n==7)?{cp1_baseaddr[31:7],i_addr_d[24:20],2'b00}:
                                 {cp1_baseaddr[31:14],i_addr_d[31:20],2'b00}):
                    (fsm_d==`search_tlb && o_search_ack_d==1 && o_read_per_d==1)?o_result_addr_d:
                    (fsm_d==`first_level && i_dcache_ack && i_dcache_data[1:0]==2'b01)?{i_dcache_data[31:10],i_addr_d[19:12],2'b00}:
                    (fsm_d==`first_level && i_dcache_ack && i_dcache_data[1:0]==2'b10  && i_dcache_data[19]==0)?{i_dcache_data[31:20],i_addr_d[19:0]}:
                    (fsm_d==`first_level && i_dcache_ack && i_dcache_data[1:0]==2'b10  && i_dcache_data[19]==1)?{i_dcache_data[31:24],i_addr_d[23:0]}:
                    (fsm_d==`second_level && i_dcache_ack && i_dcache_data[1:0]==2'b01 )?{i_dcache_data[31:16],i_addr_d[15:0]}:
                    (fsm_d==`second_level && i_dcache_ack && i_dcache_data[1:0]==2'b10 )?{i_dcache_data[31:12],i_addr_d[11:0]}:last_addr_d;

//tlb_i

assign search_tlb_addr_i=(n==1)?{1'h0,i_addr_i[30:0]}:
                         (n==2)?{2'h0,i_addr_i[29:0]}:
                         (n==3)?{3'h0,i_addr_i[28:0]}:
                         (n==4)?{4'h0,i_addr_i[27:0]}:
                         (n==5)?{5'h00,i_addr_i[26:0]}:
                         (n==6)?{6'h00,i_addr_i[25:0]}:
                         (n==7)?{7'h00,i_addr_i[24:0]}:i_addr_i;
assign i_write_tlb_i=(o_read_per_i==1 && i_icache_ack &&(fsm_i==`first_level  && i_icache_data[1:0]==2'b10)||
                   (fsm_i==`second_level && 
                     (i_icache_data[1:0]==2'b01 || 
                       (i_icache_data[1:0]==2'b10 && cp1_control[23]==0)
                     )
                   )
                 )?1:0;
assign i_type_i=(fsm_i==`first_level && i_icache_data[1:0]==2'b10 && i_icache_data[19]==1)?0:
                 (fsm_i==`first_level && i_icache_data[1:0]==2'b10 && i_icache_data[19]==0)?1:
                 (fsm_i==`second_level && i_icache_data[1:0]==2'b01)?2:
                 (fsm_i==`second_level && i_icache_data[1:0]==2'b10)?3:0;
assign i_pa_i=o_addr_i_w[31:12];
assign i_ap_i=(fsm_i==`first_level && i_icache_data[1:0]==2'b10 )?{i_icache_data[11:10],6'h00}:
              (fsm_i==`first_level)?i_icache_data[11:4]:
              (fsm_i==`second_level && cp1_control[23]==0)?i_icache_data[11:4]:{i_icache_data[5:4],6'h00};
assign i_domin_i=(fsm_i==`first_level)?i_icache_data[8:5]:domin_temp_i;
assign i_asid_i=cp13_contex[7:0];
assign i_apx_i=((fsm_i==`first_level && cp1_control[23]==0))?0:
               (fsm_i==`first_level && cp1_control[23]==1)?i_icache_data[15]:
               (fsm_i==`second_level && cp1_control[23]==1)?i_icache_data[9]:0;
tlb i_tlb
(
   .i_clk(i_clk),
   .i_rst(i_rst),
   //search tlb
   .i_search_addr(search_tlb_addr_i),  // multiplex for write tlb's va,???x
   .i_search_valid(i_read_i),
   .o_result_addr(o_result_addr_i),
   .o_domin(o_domin_i),
   .o_asid_neq(o_asid_neq_i),  //addr match,but asid not match
   .o_search_ack(o_search_ack_i),
   .o_ap(o_ap_i),
   .o_apx(o_apx_i),
   //write tlb
   .i_write(i_write_tlb_i),
   .i_type(i_type_i),     
   .i_pa(i_pa_i),
   .i_domin(i_domin_i),
   .i_asid(i_asid_i),  //multiplex for search tlb
   .i_ap(i_ap_i),
   .i_apx(i_apx_i),
   //invalidate tlb
   .i_invalidate_ifentire(i_invalidate_ifentire_i),
   .i_invalidate_ifsingle(i_invalidate_ifsingle_i),
   .i_invalidate_ifasid(i_invalidate_ifasid_i),
   .i_invalidate_mva(i_invalidate_mva_i),  //none use bit must be zero, Data on front
   .i_invalidate_asid(i_invalidate_asid_i)
);


//tlb_d

assign search_tlb_addr_d=(n==1)?{1'h0,i_addr_d[30:0]}:
                         (n==2)?{2'h0,i_addr_d[29:0]}:
                         (n==3)?{3'h0,i_addr_d[28:0]}:
                         (n==4)?{4'h0,i_addr_d[27:0]}:
                         (n==5)?{5'h00,i_addr_d[26:0]}:
                         (n==6)?{6'h00,i_addr_d[25:0]}:
                         (n==7)?{7'h00,i_addr_d[24:0]}:i_addr_d;
assign i_write_tlb_d=(((o_read_per_d==1 && i_read_d)||(o_write_per_d==1 && i_write_d==1))&&i_dcache_ack &&(fsm_d==`first_level &&  i_dcache_data[1:0]==2'b10 )||
                 (fsm_d==`second_level && 
                   (i_dcache_data[1:0]==2'b01 || 
                     (i_dcache_data[1:0]==2'b10 && cp1_control[23]==0)
                   )
                  )
                  )?1:0;
assign i_type_d=(fsm_d==`first_level && i_dcache_data[1:0]==2'b10 && i_dcache_data[19]==1)?0:
                 (fsm_d==`first_level && i_dcache_data[1:0]==2'b10 && i_dcache_data[19]==0)?1:
                 (fsm_d==`second_level && i_dcache_data[1:0]==2'b01)?2:
                 (fsm_d==`second_level && i_dcache_data[1:0]==2'b10)?3:0;
assign i_pa_d=o_addr_d_w[31:12];
assign i_ap_d=(fsm_d==`first_level && i_dcache_data[1:0]==2'b10 )?{i_dcache_data[11:10],6'h00}:
              (fsm_d==`first_level)?i_dcache_data[11:4]:
              (fsm_d==`second_level && cp1_control[23]==0)?i_dcache_data[11:4]:{i_dcache_data[5:4],6'h00};
assign i_domin_d=(fsm_d==`first_level)?i_dcache_data[8:5]:domin_temp_d;
assign i_asid_d=cp13_contex[7:0];
assign i_apx_d=((fsm_d==`first_level && cp1_control[23]==0))?0:
               (fsm_d==`first_level && cp1_control[23]==1)?i_dcache_data[15]:
               (fsm_d==`second_level && cp1_control[23]==1)?i_dcache_data[9]:0;
tlb d_tlb
(
   .i_clk(i_clk),
   .i_rst(i_rst),
   //search tlb
   .i_search_addr(search_tlb_addr_d),  // multiplex for write tlb's va,???x
   .i_search_valid(i_read_d|i_write_d),
   .o_result_addr(o_result_addr_d),
   .o_domin(o_domin_d),
   .o_asid_neq(o_asid_neq_d),  //addr match,but asid not match
   .o_search_ack(o_search_ack_d),
   .o_ap(o_ap_d),
   .o_apx(o_apx_d),
   //write tlb
   .i_write(i_write_tlb_d),
   .i_type(i_type_d),     //0 for short bits, 1 for medium bits, 2 for long bits
   .i_pa(i_pa_d),
   .i_domin(i_domin_d),
   .i_asid(i_asid_d),  //multiplex for search tlb
   .i_ap(i_ap_d),
   .i_apx(i_apx_d),
   //invalidate tlb
   .i_invalidate_ifentire(i_invalidate_ifentire_d),
   .i_invalidate_ifsingle(i_invalidate_ifsingle_d),
   .i_invalidate_ifasid(i_invalidate_ifasid_d),
   .i_invalidate_mva(i_invalidate_mva_d),  //none use bit must be zero, Data on front
   .i_invalidate_asid(i_invalidate_asid_d)
);

//permission_calculate_i
wire [1:0] o_domain_ctl_i;
wire [1:0] o_domain_ctl_d;

assign i_domin_per_i=(fsm_i==`search_tlb)?o_domin_i:i_icache_data[8:5];
assign i_ap_per_i=(fsm_i==`search_tlb)?o_ap_i:(fsm_i==`first_level)?i_icache_data[11:10]:
              (fsm_i==`second_level && cp1_control[23]==1)?i_icache_data[5:4]:
              (fsm_i==`second_level && (i_icache_data[1:0]==2'b01||i_icache_data[1:0]==2'b10) && i_addr_i[15:14]==2'b00)?i_icache_data[5:4]:
              (fsm_i==`second_level && (i_icache_data[1:0]==2'b01||i_icache_data[1:0]==2'b10) && i_addr_i[15:14]==2'b01)?i_icache_data[7:6]:
              (fsm_i==`second_level && (i_icache_data[1:0]==2'b01||i_icache_data[1:0]==2'b10) && i_addr_i[15:14]==2'b10)?i_icache_data[9:8]:
              (fsm_i==`second_level && (i_icache_data[1:0]==2'b01||i_icache_data[1:0]==2'b10) && i_addr_i[15:14]==2'b11)?i_icache_data[11:10]:0;
assign i_apx_per_i=(fsm_i==`search_tlb)?o_apx_i:(cp1_control[23]==0)?0:i_icache_data[15];
permission_calculate per_i(
  .i_domin(i_domin_per_i),
  .i_reg3(cp3_domain),
  .i_ap(i_ap_per_i),
  .i_apx(i_apx_per_i),
  .i_ifmanager(i_ifmanager),
  .o_write(o_write_per_i),   //permission
  .o_read(o_read_per_i),
  .o_domain_ctrl(o_domain_ctl_i)
  );
//permission_calculate_d

assign i_domin_per_d=(fsm_d==`search_tlb)?o_domin_d:i_dcache_data[8:5];
assign i_ap_per_d=(fsm_d==`search_tlb)?o_ap_d:(fsm_d==`first_level)?i_dcache_data[11:10]:
              (fsm_d==`second_level && cp1_control[23]==1)?i_dcache_data[5:4]:
              (fsm_d==`second_level && (i_dcache_data[1:0]==2'b01||i_dcache_data[1:0]==2'b10) && i_addr_d[15:14]==2'b00)?i_dcache_data[5:4]:
              (fsm_d==`second_level && (i_dcache_data[1:0]==2'b01||i_dcache_data[1:0]==2'b10) && i_addr_d[15:14]==2'b01)?i_dcache_data[7:6]:
              (fsm_d==`second_level && (i_dcache_data[1:0]==2'b01||i_dcache_data[1:0]==2'b10) && i_addr_d[15:14]==2'b10)?i_dcache_data[9:8]:
              (fsm_d==`second_level && (i_dcache_data[1:0]==2'b01||i_dcache_data[1:0]==2'b10) && i_addr_d[15:14]==2'b11)?i_dcache_data[11:10]:0;

assign i_apx_per_d=(fsm_d==`search_tlb)?o_apx_d:(cp1_control[23]==0)?0:i_dcache_data[15];
permission_calculate per_d(
  .i_domin(o_domin_d),
  .i_reg3(cp3_domain),
  .i_ap(i_ap_per_d),
  .i_apx(i_apx_per_d),
  .i_ifmanager(i_ifmanager),
  .o_write(o_write_per_d),   //permission
  .o_read(o_read_per_d),
  .o_domain_ctrl(o_domain_ctl_d)
  );
  
//mmu



integer i;
always @(posedge i_clk or posedge i_rst)
begin
  if(i_rst)
    begin
      i_search_valid_d<=0;
      i_search_valid_i<=0;
      fsm_i<=0;
      fsm_d<=0;
      cp0_ID<=32'b01000001000001111000000000000000;
			cp0_TLB<=32'b00000000000000000000000000000001;
			cp0_cache<=32'b00000011000101010001000101010001;
			//
			cp1_control<=32'b00000100000001010101000001110111;
			//cp1_control<=32'b00000100100001010101000001110111;
			cp1_access<=32'b00000000000000000000000000000000;
			cp2_control<=32'b00000000000000000000000000000001;
			cp2_base0<=32'b00000000000000000000000000000001;
			cp2_base1<=32'b00000000000000100000000000000001;
			
			cp3_domain<=32'd0;   //original
			//cp3_domain<=32'hffffffff;  //test use
			cp5_ins<=32'd0;
			cp5_data<=32'd0;
			cp6_ins<=32'd0;
			cp6_data<=32'd0;
			cp6_watch<=32'd0;
			cp7_cache_management<=32'd0;
			cp8_TLB_function<=32'd0;
			cp9_cache_lockdown<=32'd0;
			cp10_TLB_lockdown<=32'd0;
			cp11_DMA<=32'd0;
			cp13_FCSE<=32'd0;
			cp13_contex<=32'd0;
    end
  else if (i_cp15sel&&i_cp15write)
	    begin
		  case(i_crn)
		  4'b0001:  
		    case(i_opcode2)
			3'b000: 
			  begin
			    if (cp1_control[0]!=0)
				    cp1_control[0]<=i_cpudata[0];
				cp1_control[2:1]<=i_cpudata[2:1];
				cp1_control[10:4]<=i_cpudata[10:4];
				cp1_control[15:12]<=i_cpudata[15:12];
				cp1_control[26:21]<=i_cpudata[26:21];
			  end
			 3'b010: cp1_access[28:0]<=i_cpudata[28:0];
			default:;
			endcase
		  4'b0010:
		    case(i_opcode2)
			3'b000: 
			  begin
				case (cp1_control[2:0])
				3'b000:cp2_base0[31:14]<=i_cpudata[31:14];
				3'b001:cp2_base0[31:13]<=i_cpudata[31:13];
				3'b010:cp2_base0[31:12]<=i_cpudata[31:12];
				3'b011:cp2_base0[31:11]<=i_cpudata[31:11];
				3'b100:cp2_base0[31:10]<=i_cpudata[31:10];
				3'b101:cp2_base0[31:9]<=i_cpudata[31:9];
				3'b110:cp2_base0[31:8]<=i_cpudata[31:8];
				3'b111:cp2_base0[31:7]<=i_cpudata[31:7];
				endcase
				cp2_base0[4:3]<=i_cpudata[4:3];
				cp2_base0[2:1]<=i_cpudata[2:1];
			  end
			3'b001:
			  begin
			    cp2_base1[31:14]<=i_cpudata[31:14];
				cp2_base1[4:3]<=i_cpudata[4:3];
				cp2_base1[2:1]<=i_cpudata[2:1];
			  end
			3'b010: cp1_access[2:0]<=i_cpudata[2:0];
			default:;
			endcase
		  4'b0011: cp3_domain<=i_cpudata;
		  4'b0101: 
		    case(i_opcode2)
			3'b000: 
			  begin			    
				cp5_data[11:10]<=i_cpudata[11:10];
				cp5_data[7:0]<=i_cpudata[7:0];				
			  end
			 3'b001: 
			  begin
			    cp5_ins[3:0]<=i_cpudata[3:0];
				cp5_ins[10]<=i_cpudata[10];
			  end
			default:;
			endcase
		  4'b0110:
		    case(i_opcode2)
			3'b000: cp6_data<=i_cpudata;
			3'b001: cp6_watch<=i_cpudata;
			3'b010: cp6_ins<=i_cpudata;
			default:;
			endcase
		  4'b0111: ;
		  4'b1000: 
		    case(i_crm)
			4'b0101:
			  begin
			    if (i_opcode2==3'd0)
				  begin
				    cp8_TLB_function<=0;
					//invalid_state_i<=2'd0;
				  end
				else if (i_opcode2==3'd1)
				  begin
				    cp8_TLB_function<=i_cpudata;
					//invalid_state_i<=2'd1;					
				  end
				else if (i_opcode2==3'd2)
				  begin
				    cp8_TLB_function<=i_cpudata;
					//invalid_state_i<=2'd2;
				  end
			  end
			4'b0110:
			  begin
			    if (i_opcode2==3'd0)
				    begin
				    cp8_TLB_function<=0;
//					invalid_state_d<=2'd0;
				  end
				else if (i_opcode2==3'd1)
				  begin
				    cp8_TLB_function<=i_cpudata;
					//invalid_state_d<=2'd1;					
				  end
				else if (i_opcode2==3'd2)
				  begin
				    cp8_TLB_function<=i_cpudata;
					//invalid_state_d<=2'd2;
				  end
			  end
			4'b0111:
			  begin
			    if (i_opcode2==3'd0)
				  begin
				    cp8_TLB_function<=0;
					//invalid_state_i<=2'd0;
					//invalid_state_d<=2'd0;
				  end
				else if (i_opcode2==3'd1)
				  begin
				    cp8_TLB_function<=i_cpudata;
					//invalid_state_i<=2'd1;
					//invalid_state_d<=2'd1;					
				  end
				else if (i_opcode2==3'd2)
				  begin
				    cp8_TLB_function<=i_cpudata;
					//invalid_state_i<=2'd2;
					//invalid_state_d<=2'd2;
				  end
			  end
			default:;
			endcase			
		  4'b1001: ;
		  4'b1010: ;
		  4'b1011: ;
		  4'b1101: 
		    case(i_opcode2)
		    3'b000: cp13_FCSE[31:25]<=i_cpudata[31:25];		  
		    3'b001: cp13_contex<=i_cpudata;
		    default:;
		    endcase 
		  default:;
		  endcase
		end
  else
  begin 
    last_addr_i<=o_addr_i_w;
    last_addr_d<=o_addr_d_w;
    //mmu_i
    case(fsm_i)
      `idle:begin
            if(i_read_i)
              fsm_i<=`search_tlb;
            end
      `search_tlb:begin
                    if(o_search_ack_i)
                      begin
                        if(!o_read_per_i)
                          begin						    
							cp5_ins[10]<=0;						    
						    if (o_domain_ctl_i==2'b00)
							   begin							     								 
								 if (i_type_i<2)
									cp5_ins[3:0]<=4'b1001;	
								 else
									cp5_ins[3:0]<=4'b1011;	
							   end
							else 
								begin
								  if (i_type_i<2)
									cp5_ins[3:0]<=4'b1101;	
								  else
									cp5_ins[3:0]<=4'b1111;	
								end
                            fsm_i<=`idle;
                          end
                        else
                          begin
                            fsm_i<=`get_data;
                          end
                      end
                    else
                      begin
                        fsm_i<=`first_level;
                        
                      end
                  end
      `first_level:begin
                     if(i_icache_ack)
                       begin
                         if(i_icache_data[1:0]==2'b01)
                           begin
                             fsm_i<=`second_level;
                             domin_temp_i<=i_icache_data[8:5];
                           end
                         else if(i_icache_data[1:0]==2'b10)
                           begin
                             if(cp1_control[23]==0 && i_icache_data[18]==1)
                               begin
                                 fsm_i<=`idle;
                                 //error
                               end
							 else if (o_domain_ctl_i==2'b00)
							   begin
								 cp5_ins[10]<=0;
							     cp5_ins[3:0]<=4'b1001;
								 fsm_i<=`idle;
							   end
                             else if(o_read_per_i==0)
                               begin
                                 //error
								 cp5_ins[10]<=0;
							     cp5_ins[3:0]<=4'b1101;
                                 fsm_i<=`idle;
                               end
                             else
                               fsm_i<=`get_data;
                           end
                         else
                           begin
							 cp5_ins[10]<=0;
							 cp5_ins[3:0]<=4'b0101;
                             fsm_i<=`idle;
                           end
                       end
                   end
      `second_level:begin
                      if(i_icache_ack)
                       begin
                         if(cp1_control[23]==0)
                           begin
                             if(i_icache_data[1:0]==2'b01 && o_read_per_i==1)
                               begin
                                 fsm_i<=`get_data;
                               end
                             else if(i_icache_data[1:0]==2'b10 && o_read_per_i==1)
                               begin
                                 fsm_i<=`get_data;
                               end
                              else if (i_icache_data[1:0]==2'b00)
                               begin
							     
							     cp5_ins[10]<=0;
								 cp5_ins[3:0]<=4'b0111;
                                 fsm_i<=`idle;
                                 //error
                               end
							 else if (o_domain_ctl_i==2'b00)
							   begin
								 cp5_ins[10]<=0;
							     cp5_ins[3:0]<=4'b1011;
								 fsm_i<=`idle;
							   end
							 else if (o_read_per_i==0)
								begin
								 cp5_ins[10]<=0;
							     cp5_ins[3:0]<=4'b1111;
                                 fsm_i<=`idle;
								end
                           end
                         else 
                           begin
                             if(i_icache_data[1:0]==2'b01 && o_read_per_i==1)
                               begin
                                 fsm_i<=`get_data;
                               end
                             else
                               begin
                                 cp5_ins[10]<=0;
								 cp5_ins[3:0]<=4'b0111;
                                 fsm_i<=`idle;
                                 //error
                               end
                           end
                       end
                    end  
      `get_data:begin
                  if(i_icache_ack)
                    fsm_i<=`idle;
                end
   endcase
   
   //mmu_d
   case(fsm_d)
      `idle:begin
            if(i_read_d || i_write_d)
              fsm_d<=`search_tlb;
            end
      `search_tlb:begin
                    if(o_search_ack_d)
                      begin
                        if(!((o_read_per_d && i_read_d)||(o_write_per_d && i_write_d)))
                          begin
							cp5_data[7:4]<=i_domin_d;
							cp5_data[10]<=0;
						    if (i_read_d==1)
								cp5_data[11]<=0;
							else if (i_write_d==1)
								cp5_data[11]<=1;
						    if (o_domain_ctl_d==2'b00)
							   begin							     								 
								 if (i_type_d<2)
									cp5_data[3:0]<=4'b1001;	
								 else
									cp5_data[3:0]<=4'b1011;	
							   end
							else 
								begin
								  if (i_type_d<2)
									cp5_data[3:0]<=4'b1101;	
								  else
									cp5_data[3:0]<=4'b1111;	
								end
                            fsm_d<=`idle;
                          end
                        else
                          begin
                            fsm_d<=`get_data;
                          end
                      end
                    else
                      begin
                        fsm_d<=`first_level;
                        
                      end
                  end
      `first_level:begin
                     if(i_dcache_ack)
                       begin
                         if(i_dcache_data[1:0]==2'b01)
                           begin
                             fsm_d<=`second_level;
                             domin_temp_d<=i_dcache_data[8:5];
                           end
                         else if(i_dcache_data[1:0]==2'b10)
                           begin
                             if(cp1_control[23]==0 && i_dcache_data[18]==1)
                               begin
                                 fsm_d<=`idle;
                                 //error
                               end
							 else if (o_domain_ctl_d==2'b00)
							   begin
							     if (i_read_d==1)
									cp5_data[11]<=0;
								 else if (i_write_d==1)
									cp5_data[11]<=1;
								 cp5_data[7:4]<=i_domin_d;
								 cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1001;
								 fsm_d<=`idle;
							   end
                             else if(!((o_read_per_d && i_read_d)||(o_write_per_d && i_write_d)))
                               begin
							     if (i_read_d==1)
									cp5_data[11]<=0;
								 else if (i_write_d==1)
									cp5_data[11]<=1;
								 cp5_data[7:4]<=i_domin_d;	
								 cp5_data[10]<=0;
								 cp5_data[3:0]<=4'b1101;
                                 //error
                                 fsm_d<=`idle;
                               end
                             else
                               fsm_d<=`get_data;
                           end
                         else
                           begin
						     if (i_read_d==1)
								cp5_data[11]<=0;
							 else if (i_write_d==1)
								cp5_data[11]<=1;
						     cp5_data[7:4]<=i_domin_d;
						     cp5_data[10]<=0;
							 cp5_data[3:0]<=4'b0101;
                             fsm_d<=`idle;
                           end
                       end
                   end
      `second_level:begin
                      if(i_dcache_ack)
                       begin
                         if(cp1_control[23]==0)
                           begin
                             if(i_dcache_data[1:0]==2'b01 && ((o_read_per_d && i_read_d)||(o_write_per_d && i_write_d)))
                               begin
                                 fsm_d<=`get_data;
                               end
                             else if(i_dcache_data[1:0]==2'b10 && ((o_read_per_d && i_read_d)||(o_write_per_d && i_write_d)))
                               begin
                                 fsm_d<=`get_data;
                               end
							 else if (i_dcache_data[1:0]==2'b00)
                               begin
							     if (i_read_d==1)
									cp5_data[11]<=0;
								 else if (i_write_d==1)
									cp5_data[11]<=1;
								 cp5_data[7:4]<=i_domin_d;
							     cp5_data[10]<=0;
								 cp5_data[3:0]<=4'b0111;
                                 fsm_d<=`idle;
                                 //error
                               end
							 else if (o_domain_ctl_d==2'b00)
							   begin
							     if (i_read_d==1)
									cp5_data[11]<=0;
								 else if (i_write_d==1)
									cp5_data[11]<=1;
								 cp5_data[7:4]<=i_domin_d;
								 cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1011;
								 fsm_d<=`idle;
							   end
							 else if (i_read_d&&o_read_per_d==0)
							   begin
								 cp5_data[7:4]<=i_domin_d;
								 cp5_data[11]<=0;
								  cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1111;
                                 fsm_d<=`idle;
							   end
							 else if (i_write_d&&o_write_per_d==0)
								begin
									cp5_data[7:4]<=i_domin_d;
									cp5_data[11]<=1;
									 cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1111;
                                 fsm_d<=`idle;
								end							                             
                           end
                         else 
                           begin
                             if(i_dcache_data[1:0]==2'b01 && ((o_read_per_d && i_read_d)||(o_write_per_d && i_write_d)))
                               begin
                                 fsm_d<=`get_data;
                               end
							 else if (i_dcache_data[1:0]!=2'b01)
                               begin
							     if (i_read_d==1)
									cp5_data[11]<=0;
								 else if (i_write_d==1)
									cp5_data[11]<=1;
								 cp5_data[7:4]<=i_domin_d;
							     cp5_data[10]<=0;
								 cp5_data[3:0]<=4'b0111;
                                 fsm_d<=`idle;
                                 //error
                               end
                            else if (o_domain_ctl_d==2'b00)
							   begin
							     if (i_read_d==1)
									cp5_data[11]<=0;
								 else if (i_write_d==1)
									cp5_data[11]<=1;
								 cp5_data[7:4]<=i_domin_d;
								 cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1011;
								 fsm_d<=`idle;
							   end
							 else if (i_read_d&&o_read_per_d==0)
							   begin
								 cp5_data[7:4]<=i_domin_d;
								 cp5_data[11]<=0;
								  cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1111;
                                 fsm_d<=`idle;
							   end
							 else if (i_write_d&&o_write_per_d==0)
								begin
									cp5_data[7:4]<=i_domin_d;
									cp5_data[11]<=1;
									 cp5_data[10]<=0;
							     cp5_data[3:0]<=4'b1111;
                                 fsm_d<=`idle;
								end		
                           end
                       end
                    end  
      `get_data:begin
                  if(i_dcache_ack)
                    fsm_d<=`idle;
                end
   endcase                      
  end
end

//cp15


assign o_cpudata = 	(i_cp15sel==0) ? 32'd0 :
					(i_crn==4'b0000&&i_opcode2==3'b000) ? cp0_ID:(i_crn==4'b0000&&i_opcode2==3'b001) ? cp0_cache:(i_crn==4'b0000&&i_opcode2==3'b011) ? cp0_TLB :
					(i_crn==4'b0001&&i_opcode2==3'b000) ? cp1_control: (i_crn==4'b0001&&i_opcode2==3'b010) ? cp1_access :
				   (i_crn==4'b0010&&i_opcode2==3'b000) ?cp2_base0:(i_crn==4'b0010&&i_opcode2==3'b001)?cp2_base1:(i_crn==4'b0010&&i_opcode2==3'b010)?cp2_control:
					(i_crn==4'b0011) ? cp3_domain:
					(i_crn==4'b0101&&i_opcode2==3'b000)? cp5_data : (i_crn==4'b0101&&i_opcode2==3'b001) ? cp5_ins:
					(i_crn==4'b0110&&i_opcode2==3'b000)? cp6_data : (i_crn==4'b0110&&i_opcode2==3'b001) ? cp6_watch:(i_crn==4'b0110&&i_opcode2==3'b010)?cp6_ins:
					32'd0;

always @(posedge i_clk)
  begin
	

 end
  


endmodule