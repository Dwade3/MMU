`define tlbsize 256
module tlb
(
   input i_clk,
   input i_rst,
   //search tlb
   input [31:0] i_search_addr,  // multiplex for write tlb's va,???x
   input i_search_valid,
   output [31:0] o_result_addr,
   output [3:0] o_domin,
   output o_asid_neq,  //addr match,but asid not match
   output o_search_ack,
   output [1:0] o_ap,
   output o_apx,
   //write tlb
   input i_write,
   input [1:0] i_type,     //0 for supersection, 1 for section, 2 large page,3 for small page
   input [31:12] i_pa,
   input [3:0] i_domin,
   input [7:0] i_asid,  //multiplex for search tlb
   input [11:4] i_ap,
   input i_apx,
   //invalidate tlb
   input i_invalidate_ifentire,
   input i_invalidate_ifsingle,
   input i_invalidate_ifasid,
   input [31:12] i_invalidate_mva,  //none use bit must be zero, Data on front
   input [7:0] i_invalidate_asid
);

reg valid[0:`tlbsize-1];
reg [1:0] type[0:`tlbsize-1];
reg [31:12] va[0:`tlbsize-1];  //virtual addr
reg [31:12] pa[0:`tlbsize-1];  //phy addr
reg [3:0] domin[0:`tlbsize-1];
reg [7:0] asid[0:`tlbsize-1];
reg [11:4] ap[0:`tlbsize-1];
reg apx[0:`tlbsize-1];
reg [7:0] write_index;

reg [31:0]o_result_addr_g;
reg [3:0]o_domin_g;
reg o_search_ack_g;
reg o_asid_neq_g;
reg [1:0] o_ap_g;
reg o_apx_g;

assign o_result_addr=o_result_addr_g;
assign o_domin=o_domin_g;
assign o_search_ack=o_search_ack_g;
assign o_asid_neq=o_asid_neq_g;
assign o_ap=o_ap_g;
assign o_apx=o_apx_g;

integer i;
always @(posedge i_clk)
begin
  o_asid_neq_g=0;
  o_search_ack_g=0;  //reset
  if(i_rst)
    begin
      for(i=0;i<`tlbsize;i=i+1)
      begin
        valid[i]<=0;
        type[i]<=0;
        va[i]<=0;
        pa[i]<=0;
        domin[i]<=0;
        asid[i]<=0;
        ap[i]<=0;
        apx[i]<=0;
      end
      write_index<=0; 
      o_domin_g<=0;
      o_result_addr_g<=0;
      o_ap_g<=0;
      o_apx_g<=0;
    end
    else if(i_write)   //write tlb
      begin
        valid[write_index]<=1;
        type[write_index]<=i_type;
        domin[write_index]<=i_domin;
        asid[write_index]<=i_asid;
        apx[write_index]<=i_apx;
        if(i_type==0)
          begin
            va[write_index]<={i_search_addr[31:20],8'h00};
            pa[write_index]<={i_pa[31:24],8'h00};
            ap[write_index]<={i_ap[11:10],6'h00};
          end
        else if(i_type==1)
          begin
            va[write_index]<={i_search_addr[31:20],8'h00};
            pa[write_index]<={i_pa[31:20],8'h00};
            ap[write_index]<={i_ap[11:10],6'h00};
          end
        else if(i_type==2)
          begin
            va[write_index]<=i_search_addr[31:12];
            pa[write_index]<={i_pa[31:16],4'h0};
            ap[write_index]<=i_ap;
          end
        else if(i_type==3)
          begin
            va[write_index]<=i_search_addr[31:12];
            pa[write_index]<=i_pa[31:12];
            ap[write_index]<=i_ap;
          end
          write_index<=(write_index==8'hff)?0:(write_index+1);
      end
    else if(i_invalidate_ifentire==1)   //invalidate tlb
    begin
      for(i=0;i<`tlbsize;i=i+1)
      begin
        valid[i]<=0;
      end
    end
    else if(i_invalidate_ifsingle==1)   
    begin
      for(i=0;i<`tlbsize;i=i+1)
      begin
        if(i_invalidate_mva==va[i])
           valid[i]<=0;
      end
    end
    else if(i_invalidate_ifasid==1)   
    begin
      for(i=0;i<`tlbsize;i=i+1)
      begin
        if(i_invalidate_asid==asid[i])
           valid[i]<=0;
      end
    end
    else if(i_search_valid)   //search tlb
    begin
      for(i=0;i<`tlbsize;i=i+1)  
      begin
        if(valid[i]==1 && i_search_addr[31:20]==va[i][31:20])
          begin
            if(type[i]==0)
              begin
                if(i_asid==asid[i])
                  begin
                    o_domin_g<=domin[i];
                    o_result_addr_g<={pa[i][31:24],i_search_addr[23:0]};
                    o_search_ack_g<=1;
                    o_ap_g<=ap[i][11:10];
                    o_apx_g<=apx[i];
                  end
                else
                  o_asid_neq_g<=1;
              end
            else if(type[i]==1)
              begin
                if(i_asid==asid[i])
                  begin
                    o_domin_g<=domin[i];
                    o_result_addr_g<={pa[i][31:20],i_search_addr[19:0]};
                    o_search_ack_g<=1;
                    o_ap_g<=ap[i][11:10];
                    o_apx_g<=apx[i];
                  end
                else
                  o_asid_neq_g<=1;
              end
            else if(type[i]==2 && i_search_addr[19:12]==va[i][19:12])
              begin
                if(i_asid==asid[i])
                  begin
                    o_domin_g<=domin[i];
                    o_result_addr_g<={pa[i][31:16],i_search_addr[15:0]};
                    o_search_ack_g<=1;
                    o_apx_g<=apx[i];
                    case(i_search_addr[15:14])
                      0:o_ap_g<=ap[i][5:4];
                      1:o_ap_g<=ap[i][7:6];
                      2:o_ap_g<=ap[i][9:8];
                      3:o_ap_g<=ap[i][11:10];
                    endcase 
                  end
                else
                  o_asid_neq_g<=1;
              end
            else if(type[i]==3 && i_search_addr[19:12]==va[i][19:12])
              begin
                if(i_asid==asid[i])
                  begin
                   o_domin_g<=domin[i];
                   o_result_addr_g<={pa[i][31:12],i_search_addr[11:0]};
                   o_search_ack_g<=1;
                   case(i_search_addr[15:14])
                      0:o_ap_g<=ap[i][5:4];
                      1:o_ap_g<=ap[i][7:6];
                      2:o_ap_g<=ap[i][9:8];
                      3:o_ap_g<=ap[i][11:10];
                   endcase
                   o_apx_g<=apx[i];
                  end
                else
                  o_asid_neq_g<=1;
              end
          end
      end
    end
end

endmodule