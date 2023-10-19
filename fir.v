module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    //axi-lite write:0,1,寫,2,3,4
    output  wire                     awready,//addr write ready 2
    output  wire                     wready,//write ready3
    input   wire                     awvalid,//addr write valid 1
    input   wire [(pADDR_WIDTH-1):0] awaddr,//addr write 0
    input   wire                     wvalid,//write valid 4
    input   wire [(pDATA_WIDTH-1):0] wdata,//write data 0
    //axi-lite read:0,1,2,3,4
    output  wire                     arready,//addr read ready 2
    input   wire                     rready,//read ready 3
    input   wire                     arvalid,//addr read valid 1
    input   wire [(pADDR_WIDTH-1):0] araddr,//addr read 0
    output  wire                     rvalid,//read valid 4
    output  wire [(pDATA_WIDTH-1):0] rdata,//read data  0
    //axi-stream write
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready,
    // axi-stream read
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n


);
////////////////////////////////////////////////////////////////
//                  write coefficient                         //
////////////////////////////////////////////////////////////////
//--------------------------reg &wire--------------------------
parameter idle =3'b000;
parameter zero =3'b001;
parameter await=3'b010;
parameter write=3'b011;
parameter mac  =3'b100;
parameter out_yn = 3'b101;
reg [5:0] counter_w,counter_r;//bram cnt
reg [3:0] mac_cnt_w,mac_cnt_r;
reg [2:0] state_w,state_r;
reg ss_tready_w,ss_tready_r;
reg [3:0] data_WE_w;//data_WE_r;
//reg data_EN_w;//data_EN_r;
reg [(pDATA_WIDTH-1):0] data_Di_w;//data_Di_r;
reg [(pADDR_WIDTH-1):0] data_A_w;//data_A_r;
reg [11:0] inputcount_w,inputcount_r;
reg [11:0] cycleaddr_w,cycleaddr_r;
reg signed [31:0] acccccccccccccccccccccccc_w,acccccccccccccccccccccccc_r;


reg [31:0] data_length_w,data_length_r;
reg                arvalid_w,arvalid_r;
reg wready_w ;
reg awready_w;
reg [3:0] tap_WE_w ;
reg tap_EN_w;
reg [(pADDR_WIDTH-1):0] tap_A_w;
reg [(pDATA_WIDTH-1):0] tap_Di_w;
reg [11:0] tapcont_w,tapcont_r;
reg arready_w;
reg rvalid_w;
reg [(pDATA_WIDTH-1):0] rdata_w;
//--------------------------combinational block--------------
//write in axi-lite bram check57-62!
assign wready =wready_w;
assign awready=awready_w;
assign tap_WE =tap_WE_w;
assign tap_EN =1;
//assign tap_EN =tap_EN_w;
assign tap_A=tap_A_w;
assign tap_Di=tap_Di_w;
always @(*) begin
    tapcont_w =(state_r==5 || counter_r ==50)?0:tapcont_r;

    wready_w=(wvalid)?1:0;
    awready_w=(awvalid)?1:0;
    tap_WE_w=(awvalid)?4'b1111:4'b0000;
    tap_EN_w=(awvalid || arvalid)?1'b1:1'b0;
    
    /*if(state_r == 4) begin
        tapcont_w = (tapcont_r==40)?0:tapcont_r + 4;
        tap_A_w = tapcont_r;
    end else if (awvalid)begin
        tap_A_w = awaddr-12'h20;
    end else if (arvalid)begin
        tap_A_w = araddr-12'h20;
    end*/
    if (state_r == 4 || state_r == 3) begin
        tapcont_w = (tapcont_r==40)?0:tapcont_r + 4; 
    end
    tap_A_w=(awvalid&& (state_r ==2 || state_r ==1))?awaddr-12'h20:((arvalid && state_r ==2)?araddr-12'h20:tapcont_r);
    tap_Di_w=(wvalid)?wdata:0;
    data_length_w=data_length_r;
    if(awaddr==12'h10) data_length_w=wdata;
end
//read axi-lite bram & check
assign arready=arready_w;
assign rvalid=rvalid_w;//sth wrong
assign rdata=rdata_w;
assign sm_tvalid = (state_r == 5)?1:0;
assign sm_tdata = acccccccccccccccccccccccc_r;
always @(*) begin
    arready_w=(arvalid)?1:0;
    rvalid_w=(arvalid_r)?1:0;
    rdata_w=tap_Do;
    arvalid_w=arvalid;
end
//--------------------------sequential block-------------------
always @(posedge axis_clk or negedge axis_rst_n) begin
    if (!axis_rst_n) begin
       data_length_r <= 0;
       arvalid_r <= 0; 
    end else begin
        data_length_r <= data_length_w;
        arvalid_r <= arvalid_w; 
    end
end

////////////////////////////////////////////////////////////////
//                  write data                                //
////////////////////////////////////////////////////////////////
//--------------------------parameter & reg &wire------------

//--------------------------combinational block--------------
//write in axi-stream bram
//FSM BEGIN
always @(*) begin
   case (state_r)
    idle:                     state_w=zero;
    zero:begin
        if(counter_r==10'd10) state_w= await;
        else                  state_w=state_r;
    end
    await:begin
        if(counter_r==10'd50) state_w=write;
        else                  state_w=state_r;
    end                     
    write:                     state_w=mac;
    mac:begin
        if(counter_r==10'd10) state_w=out_yn;
        else                  state_w=state_r;
    end                     
    out_yn:begin
        state_w = write;
    end           
    default:state_w=state_r; 
   endcase 
end
//FSM END
assign ss_tready=ss_tready_r;
assign data_WE=data_WE_w;
assign data_EN=1;
//assign data_EN=data_EN_w;
assign data_Di=(state_r == 1)?0:ss_tdata;
assign data_A=data_A_w;
always @(*) begin
cycleaddr_w = cycleaddr_r;
inputcount_w = inputcount_r;
counter_w=0;
    case (state_r)
    idle:begin
        ss_tready_w=0;
    end
    zero:begin
        ss_tready_w=0;
        //cnt
        counter_w=counter_r+1;
        if(counter_r==10'd10) begin
            counter_w=0;
        end
        //輸出0
        data_WE_w=4'b1111;
        data_Di_w=0;
        data_A_w=counter_r<<2;
    end
    await:begin
        counter_w=counter_r+1;
        data_WE_w=0;
        if(counter_r==10'd50) begin
            counter_w=0;
            ss_tready_w=1;
            data_Di_w=ss_tdata;
            data_A_w= 0;
            acccccccccccccccccccccccc_w = 0;
        end
    end
    write:begin //要input data 準備mac開始的input直
        ss_tready_w=0;
        counter_w=counter_r;
        inputcount_w=(inputcount_r ==40)?0:inputcount_r+4;
        cycleaddr_w = (inputcount_r==0)?40:inputcount_r-4;
        data_WE_w=4'b1111;
    end
    mac:begin
        counter_w=counter_r+1;//幫Write
        cycleaddr_w = (cycleaddr_r==0)?40:cycleaddr_r-4;
        data_A_w = cycleaddr_r;
        if(counter_r==10'd10) begin
            counter_w=0;
        end else begin
            ss_tready_w=0;
            data_WE_w=4'b0000;
        end
        acccccccccccccccccccccccc_w=(counter_r==10'd0)?0:($signed(data_Do)*$signed(tap_Do)+acccccccccccccccccccccccc_r);
    end
    out_yn:begin
        //做下一筆資料需要的addr
        //output data
        ss_tready_w=1;
        data_A_w = inputcount_r;

    end   
       
     
   endcase 
end
always @(posedge axis_clk or negedge axis_rst_n ) begin
    if (!axis_rst_n) begin
        state_r <= 0;
        counter_r <= 0;
        ss_tready_r<=0;
        mac_cnt_r<=0; 
        inputcount_r <= 0;
        acccccccccccccccccccccccc_r <= 0;
        cycleaddr_r <= 0;
        tapcont_r <= 0;
     end else begin
        state_r     <= state_w;
        counter_r   <= counter_w;
        ss_tready_r <= ss_tready_w;
        mac_cnt_r   <= mac_cnt_w;
        inputcount_r <= inputcount_w; 
        acccccccccccccccccccccccc_r <= acccccccccccccccccccccccc_w;
        cycleaddr_r <= cycleaddr_w;
        tapcont_r <= tapcont_w;
     end
end
endmodule