-- Company: 
-- Engineer: Qihsi Hu 
-- Create Date: 12/05/2024 08:04:50 PM
-- Design Name: 
-- Module Name: hdmi_design
-- Description: top moudle

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity SLI_Offline is
    Port ( 
        clk100    : in STD_LOGIC;
        led           : out   std_logic_vector(7 downto 0) :=(others => '0');
        sw            : in    std_logic_vector(7 downto 0) :=(others => '0');
        en : out    std_logic_vector(3 downto 0) :=(others => '1'); -- 7 seg enable
        seg : out    std_logic_vector(7 downto 0) :=(others => '1');
        BTNL: in std_logic; --left button (vancant, orginally for switch mode)
        BTNT: in std_logic; --top button (vacant, orginally for toggling slow motion)
        BTNR: in std_logic; --right button (reset hdmi_out)
        -- four-line handsake signals for two camera interfaces
        C1_out : out    std_logic_vector(1 downto 0);
        C1_in : in    std_logic_vector(1 downto 0);
        C2_out : out    std_logic_vector(1 downto 0);
        C2_in : in    std_logic_vector(1 downto 0);
       -- VS    : out STD_LOGIC;
       -- fg : out STD_LOGIC;
       
       -- Micro SD
       sd_clk: out   std_logic;
       sd_cs: out   std_logic;
       sd_mosi: out   std_logic;
       sd_miso: in   std_logic;
  
        --- HDMI out
--        hdmi_tx_cec   : inout std_logic;
        hdmi_tx_clk_n : out   std_logic;
        hdmi_tx_clk_p : out   std_logic;
--        hdmi_tx_hpd   : in    std_logic;
--        hdmi_tx_rscl  : inout std_logic;
--        hdmi_tx_rsda  : inout std_logic;
        hdmi_tx_p     : out   std_logic_vector(2 downto 0);
        hdmi_tx_n     : out   std_logic_vector(2 downto 0)     
    );
end SLI_Offline;

architecture Behavioral of SLI_Offline is
    -- sd signals
    signal file_found : std_logic;
    signal sd_cs_buf: std_logic;
    signal sd_clk_buf: std_logic;
    component ref_clk is
    Port (
        clk_in    : in STD_LOGIC;    
        clk_out : out STD_LOGIC;
        clk10 : out STD_LOGIC;
        clk75 : out STD_LOGIC;
        clk375 : out STD_LOGIC
    );
    end component;
    
    component vga is
    Port ( pixelClock : in  STD_LOGIC;
           Red        : out STD_LOGIC_VECTOR (7 downto 0);
           Green      : out STD_LOGIC_VECTOR (7 downto 0);
           Blue       : out STD_LOGIC_VECTOR (7 downto 0);
           hSync      : out STD_LOGIC;
           vSync      : out STD_LOGIC;
           blank      : out STD_LOGIC);
    end component;
    
    component DVID_output is
    Port ( 
        pixel_clk       : in std_logic;  -- Driven by BUFG
        pixel_io_clk_x1 : in std_logic;  -- Driven by BUFIO
        pixel_io_clk_x5 : in std_logic;  -- Driven by BUFIO
        -- VGA Signals
        vga_blank       : in  std_logic;
        vga_hsync       : in  std_logic;
        vga_vsync       : in  std_logic;
        vga_red         : in  std_logic_vector(7 downto 0);
        vga_blue        : in  std_logic_vector(7 downto 0);
        vga_green       : in  std_logic_vector(7 downto 0);
        data_valid      : in  std_logic;
        
        --- HDMI out
       outclk_p : out std_logic;
        tmds_out_clk    : out   std_logic;
        tmds_out_ch0    : out   std_logic;
        tmds_out_ch1    : out   std_logic;
        tmds_out_ch2    : out   std_logic
    );
    end component;
    signal clk200  : std_logic;
    signal clk10  : std_logic;
    signal clk75  : std_logic;
    signal clk375  : std_logic;
    signal local_pclk  : std_logic;
    signal local_pclkx5 : std_logic;
    signal local : std_logic := '0';
    signal symbol_sync  : std_logic;
    signal symbol_ch0   : std_logic_vector(9 downto 0);
    signal symbol_ch1   : std_logic_vector(9 downto 0);
    signal symbol_ch2   : std_logic_vector(9 downto 0);
    signal debug_pmod    :   std_logic_vector(7 downto 0) :=(others => '0');
    signal tmds_out_clk : std_logic;
    signal tmds_out_ch0 : std_logic;
    signal tmds_out_ch1 : std_logic;
    signal tmds_out_ch2 : std_logic;
    
    signal sel: std_logic;
    
    component pixel_pipe is
        Port ( clk : in STD_LOGIC;  clk10 : in STD_LOGIC; 
        bt : in std_logic_vector(1 downto 0); -- push button 
        sw : in std_logic_vector(7 downto 0); -- switches
         en : out    std_logic_vector(3 downto 0); -- 7 seg enable
        seg : out    std_logic_vector(7 downto 0);
        LUT_rdy   : out STD_LOGIC;
        trig    : out STD_LOGIC;  f_frm   : out STD_LOGIC; 
        mode    : in STD_LOGIC;  rdy   : in STD_LOGIC;  
            ------------------
            in_blank  : in std_logic;
            in_hsync  : in std_logic;
            in_vsync  : in std_logic;
            in_red    : in std_logic_vector(7 downto 0);
            in_green  : in std_logic_vector(7 downto 0);
            in_blue   : in std_logic_vector(7 downto 0);

            -------------------
            out_blank : out std_logic;
            out_hsync : out std_logic;
            out_vsync : out std_logic;
            out_red   : out std_logic_vector(7 downto 0);
            out_green : out std_logic_vector(7 downto 0);
            out_blue  : out std_logic_vector(7 downto 0);
            ---SD signals--
            sd_clk: out   std_logic;
            sd_cs: out   std_logic;
            sd_mosi: out   std_logic;
            sd_miso: in   std_logic;
            file_found: out   std_logic
            
    );
    end component;

    signal not_C1in1: std_logic;
    signal pixel_clk : std_logic;
    signal in_blank  : std_logic;
    signal in_hsync  : std_logic;
    signal in_vsync  : std_logic;
    signal in_red    : std_logic_vector(7 downto 0);
    signal in_green  : std_logic_vector(7 downto 0);
    signal in_blue   : std_logic_vector(7 downto 0);
    signal is_interlaced   : std_logic;
    signal is_second_field : std_logic;
    signal out_blank : std_logic;
    signal out_hsync : std_logic;
    signal out_vsync : std_logic;
    signal out_red   : std_logic_vector(7 downto 0);
    signal out_green : std_logic_vector(7 downto 0);
    signal out_blue  : std_logic_vector(7 downto 0);

    signal audio_channel : std_logic_vector(2 downto 0);
    signal audio_de      : std_logic;
    signal audio_sample  : std_logic_vector(23 downto 0);
    signal trig : std_logic;
    signal f_frm : std_logic;
    signal debug : std_logic_vector(7 downto 0);
begin
    debug_pmod <= debug;    
    led  (7 downto 6)      <= debug (7 downto 6);
    -- for test GPIO input pins
    --led (5)   <= C1_in(1);    led (4)   <= C1_in(0);     led (3)   <= C2_in(1);    led (2)   <= C2_in(0);
    
    -- for SD debugging
    --led (5) <= file_found; 
    -- verify clock selector
    --led (4)   <= sel;    
    led(4) <= sw(1);
    
        
    -- 4-line protocl pins
    led(3) <= C1_in(1); --mode;
    led(2) <= C1_in(0); --rdy;    
    led (1)   <= f_frm;
    led (0)   <= trig;

    C1_out(0)  <= trig; 
    C1_out(1)  <= f_frm;

    
    C2_out(0)  <= trig; C2_out(1)  <= f_frm;
    
i_DVID_input: vga port map(
     pixelClock => clk75,
           Red       =>in_red,
           Green     =>in_green,
           Blue     =>in_blue,
           hSync    =>in_hsync,
           vSync     =>in_vsync,
           blank     =>in_blank
);
 
i_DVID_output: DVID_output port map ( 
    outclk_p => open,
        pixel_clk       => clk75,
        pixel_io_clk_x1 => clk75,
        pixel_io_clk_x5 => clk375,
--       pixel_clk       => oclk,
--       pixel_io_clk_x1 => oclk1,
--       pixel_io_clk_x5 => oclk5,
        data_valid      => BTNR,
        -- VGA Signals
        vga_blank     => out_blank,
        vga_hsync     => out_hsync,
        vga_vsync     => out_vsync,
        vga_red       => out_red,
        vga_blue      => out_blue,
        vga_green     => out_green,
        
        --- HDMI out
        tmds_out_clk  => tmds_out_clk,
        tmds_out_ch0  => tmds_out_ch0,
        tmds_out_ch1  => tmds_out_ch1,
        tmds_out_ch2  => tmds_out_ch2
    );
 
ref_clk_pll : ref_clk
    port map (
        clk_in  => clk100,    
        clk_out => clk200,
        clk75 => clk75, clk375 => clk375,
        clk10 => clk10
    );
sd_cs <= sd_cs_buf; 
sd_clk <= sd_clk_buf;

process(in_vsync)
    begin
        not_C1in1<=not C1_in(1);
    end process;
i_processing: pixel_pipe Port map ( 
        clk => clk75, clk10 => clk10,
        en  =>  en, seg => seg, sw =>sw,
        trig =>trig, f_frm=> f_frm, 
        mode=> not_C1in1, rdy=> C1_in(0),
        LUT_rdy => led (5),
        bt => BTNT & BTNL,
        --SD signals
        sd_clk=> sd_clk_buf, sd_cs =>sd_cs_buf,
        sd_mosi=>sd_mosi, sd_miso=>sd_miso, file_found=>file_found,        
        --
        in_blank        => in_blank,
        in_hsync        => in_hsync,
        in_vsync        => in_vsync,
        in_red          => in_red,
        in_green        => in_green,
        in_blue         => in_blue,    
        out_blank => out_blank,
        out_hsync => out_hsync,
        out_vsync => out_vsync,
        out_red   => out_red,
        out_green => out_green,
        out_blue  => out_blue
    );

out_clk_buf: OBUFDS    port map ( O  => hdmi_tx_clk_p, OB => hdmi_tx_clk_n, I => tmds_out_clk);
    
out_tx0_buf: OBUFDS    port map ( O  => hdmi_tx_p(0), OB => hdmi_tx_n(0), I  => tmds_out_ch0);

out_tx1_buf: OBUFDS    port map ( O  => hdmi_tx_p(1), OB => hdmi_tx_n(1), I  => tmds_out_ch1);

out_tx2_buf: OBUFDS    port map ( O  => hdmi_tx_p(2), OB => hdmi_tx_n(2), I  => tmds_out_ch2);
    
end Behavioral;