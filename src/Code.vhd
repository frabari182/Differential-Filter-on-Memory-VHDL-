----------------------------------------------------------------------------------
-- Students: Barillari Francesco - Benvenuti Andrea Roberto
--
-- Create Date: 29.07.2025 12:34:53
-- Design Name:
-- Module Name: project_reti_logiche - Behavioral
-- Project Name: Progetto Reti logiche - Politecnico di Milano
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created

----------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);

        o_done : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );
end project_reti_logiche;

-- ARCHITECTURE

-- PROCESSI COMBINATORI

architecture Behavioral of project_reti_logiche is

    signal k_load : std_logic;
    signal s_load : std_logic;
    signal f_load, SR_load, n_load : std_logic;

    signal addr_sel : std_logic_vector (1 downto 0);
    signal curr_addr : std_logic_vector(15 downto 0);
    signal last : std_logic;
   
    signal SR_read, coeff_read : std_logic;

    type S is (IDLE, ASK_L, WAIT_L, REG_K, REG_S, ASK_W, ADD_W, WAIT_W, TAKE_COEFF, WAIT_COEFF, COMPUTE, NORMALIZE, ASK_R, WRITE_R, WAIT_R, DONE);
    signal curr_state, next_state : S;
    signal count : integer := 0;
   
    signal regK : std_logic_vector(15 downto 0);
    signal regS : std_logic;
    signal first_SR, can_write : std_logic;

    signal win : std_logic_vector(55 downto 0);  -- 7 byte
    signal partial_result  : signed(18 downto 0) := (others => '0');

    signal normalized : signed(7 downto 0);

begin

    -- Signals Process: abilita accesso alla memoria e il caricamento nei registri
    process(curr_state, count, last, k_load, can_write, s_load)
    begin
        -- default values
        s_load     <= '0';
        f_load     <= '0';
        SR_load    <= '0';
        o_mem_en   <= '0';
        o_mem_we   <= '0';
        k_load <= '0';
        n_load <= '0';
        can_write <= '0';
               
        case curr_state is
            when IDLE =>
            when ASK_L =>
                o_mem_en <= '1';
            when WAIT_L => o_mem_en <= '1';
            when REG_K => k_load <= '1';
            when REG_S =>
                s_load <= '1';
                if s_load = '1' then
                    o_mem_en <= '1';
                end if;
            when ASK_W => o_mem_en <= '1';
            when ADD_W =>
                SR_load <= '1';
                o_mem_en <= '1';
            when WAIT_W =>
                o_mem_en <= '1';    
            when TAKE_COEFF =>
            when WAIT_COEFF => o_mem_en <= '1';
            when COMPUTE => f_load <= '1';
            when NORMALIZE => n_load <= '1';
            when ASK_R =>
                can_write <= '1';
            when WRITE_R =>  
                o_mem_en <= '1';
                o_mem_we <= '1';            
            when WAIT_R =>
               o_mem_en <= '1';
            when DONE =>      
            when others =>    
        end case;
    end process;

    -- Next_State Process: definisce le transizioni della FSM, sulla base di condizioni logiche e segnali di stato
    process(curr_state, i_start, count, first_SR, last, i_mem_data, addr_sel, coeff_read, SR_read)

    begin
        next_state <= curr_state;  -- default
        case curr_state is
            when IDLE =>
                if i_start = '1' then
                    next_state <= ASK_L;
                else
                    next_state <= IDLE;
                end if;
            when ASK_L =>
                next_state <= WAIT_L;
            when WAIT_L =>
                if count = 0 or count = 1 then -- K1 e K2
                    next_state <= REG_K;
                elsif count = 2 then
                    next_state <= REG_S; -- S
                end if;
            when REG_K =>
                next_state <= ASK_L;
            when REG_S =>
                next_state <= ASK_W;    
            when ASK_W =>
                next_state <= WAIT_W;
            when ADD_W =>
                if count < 4 and first_SR = '1' then -- per il primo riempimento della finestra
                    next_state <= WAIT_W;
                end if;    
                if count = 4 or (addr_sel = "01" and first_SR = '0') then -- dal secondo in poi
                    next_state <= TAKE_COEFF;
                end if;
            when WAIT_W =>
                if SR_read = '1' then -- parola pronta per essere inserita nella finestra
                    next_state <= ADD_W;    
                end if;
            when TAKE_COEFF =>
                if count < 7 then -- calcolo risultato
                    next_state <= WAIT_COEFF;
                else
                    next_state <= NORMALIZE; -- fine calcolo
                end if;
            when WAIT_COEFF =>
                if coeff_read = '1' then -- coefficiente pronto per essere usato nel calcolo
                    next_state <= COMPUTE;
                end if;    
            when COMPUTE =>
                next_state <= TAKE_COEFF;  
            when NORMALIZE =>
                next_state <= ASK_R;
            when ASK_R =>
                next_state <= WRITE_R;
            when WRITE_R =>
                next_state <= WAIT_R;
            when WAIT_R =>
                if last = '1' then  -- fine sequenza di input
                    next_state <= DONE;
                elsif last ='0' then
                    next_state <= ASK_W; -- ricomincia il ciclo di lettura, calcolo e scrittura
                end if;
            when DONE =>
                if i_start = '0' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;

    -- PROCESSI SEQUENZIALI
   
    -- Processo di aggiornamento dei segnali di indirizzamento e sincronizzazione memoria (count, addr_sel, first_SR, curr_addr)
    -- si è deciso di raggruppare l'aggiornamento dei segnali utili alla logica dell'FSM all'interno di un unico processo per maggiore leggibilità
    process(i_clk, i_rst)

    begin
        if i_rst = '1' then
            count <= 0;
            addr_sel <= "00";  
        elsif rising_edge(i_clk) then
            SR_read <= '0';
            coeff_read <= '0';
            case curr_state is
                when IDLE =>
                    count <= 0;
                    addr_sel <= "00";
                    curr_addr <= "0000000000000000";
                    first_SR <= '1';
                when ASK_L =>
                when WAIT_L =>
                when REG_K =>
                    count <= count + 1;
                when REG_S =>
                    count <= 0;
                    addr_sel <= "10"; -- preparazione o_mem_addr per la lettura delle parole
                    curr_addr <= std_logic_vector( unsigned(i_add) + 19);
                when ASK_W =>
                    curr_addr <= std_logic_vector( unsigned(curr_addr) + 1);
                when ADD_W =>
                    if count < 4 and first_SR = '1' then
                        count <= count + 1;
                    elsif count = 4 or first_SR = '0' then -- per la prima parola count = 4, dalla seconda first Sr = 0
                        count <= 0;
                        if first_SR = '1' then
                            first_SR <= '0';  -- fine primo riempimento
                        end if;
                        addr_sel <= "01";  -- passaggio ai coefficienti filtro
                    end if;
                when WAIT_W =>
                    SR_read <= '1';
                when TAKE_COEFF =>
                when WAIT_COEFF =>
                    coeff_read <= '1';
                when COMPUTE =>
                    count <= count + 1;
                when NORMALIZE =>
                    count <= 0;
                    addr_sel <= "11";  -- perparazione o mem addr corretto per scrittura
                when ASK_R =>
                when WRITE_R =>
                    addr_sel <= "10";  -- preparazione o mem addr corretto parola
                when WAIT_R =>
                when DONE =>
            end case;
        end if;
    end process;


    -- FSM process: aggiorna lo stato corrente della FSM al fronte di clòck
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            curr_state <= IDLE;
        elsif rising_edge(i_clk) then
            curr_state <= next_state;
        end if;
    end process;

    -- DATAPATH
   
    -- Processo di caricamento di regK: registro a scorrimento comodo per calcolare K
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then
            regK <= (others => '0');
        elsif rising_edge(i_clk) and (k_load = '1') then
            if count = 0 then
                regK <= regK(7 downto 0) & i_mem_data;
            elsif count = 1 then
                regK <= regK(7 downto 0) & i_mem_data;
            end if;
        end if;
    end process;

    -- Processo di caricamento regS: memorizza il tipo di filtro usato
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then
            regS <= '0';
        elsif rising_edge(i_clk) and s_load = '1' then
            if count = 2 then
                if i_mem_data = "00000000" then
                    regS <= '0';
                elsif i_mem_data = "00000001" then
                    regS <= '1';
                end if;
               
            end if;
        end if;
    end process;



    -- Processo di caricamento W: aggiorna il registro a scorrimento win
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            win <= (others => '0');
        elsif rising_edge(i_clk) and SR_load = '1' and count /= 4 then
            if curr_addr >= std_logic_vector( unsigned(i_add) + 17 + unsigned(regK)) and addr_sel /= "01" then -- caso di fine sequenza: inserimento di 0 negli ultimi slot della finestra
                win <= win(47 downto 0) & "00000000";
            elsif curr_addr > std_logic_vector( unsigned(i_add) + 16) and addr_sel /= "01" then -- caso standard: inserimento della nuova parola nella finestra
                win <= win(47 downto 0) & i_mem_data;
            end if;

        end if;
    end process;


    -- Processo di calcolo parziale: prodotto tra parola e coefficiente e aggiornamento di partial_result
    process(i_clk, i_rst)
        variable selected_word : signed(7 downto 0);
        variable coeff         : signed(7 downto 0);
        variable product       : signed(18 downto 0);
        variable acc           : signed(18 downto 0);
    begin
        if i_rst = '1' then
            partial_result <= (others => '0');
        elsif rising_edge(i_clk) and f_load = '1' and count < 7 then
            -- Estrai il byte corretto dalla finestra
            case count is
                when 0 => selected_word := signed(win(55 downto 48));
                when 1 => selected_word := signed(win(47 downto 40));
                when 2 => selected_word := signed(win(39 downto 32));
                when 3 => selected_word := signed(win(31 downto 24));
                when 4 => selected_word := signed(win(23 downto 16));
                when 5 => selected_word := signed(win(15 downto 8));
                when 6 => selected_word := signed(win(7 downto 0));
                when others =>
            end case;
   
            coeff   := signed(i_mem_data);
            product := resize(coeff * selected_word, 19);          
            acc     := partial_result + product;
   
            -- Moltiplicazione accumulata: inizializzazione partial_result
            if count = 0 then
                partial_result <= product;
            else
                partial_result <= acc;
            end if;
           
        end if;
    end process;


    -- Processo di normalizzazione: produzione del risultato normalizzato
    process(i_clk, i_rst)
        variable v       : signed(18 downto 0);
        variable temp    : signed(18 downto 0);
        variable sh1     : signed(18 downto 0);
        variable sh2     : signed(18 downto 0);
        variable sh3     : signed(18 downto 0);
        variable sh4     : signed(18 downto 0);
    begin
        if i_rst = '1' then
            normalized <= (others => '0');
        elsif rising_edge(i_clk) and n_load = '1' then
            -- Valore da normalizzare
            v := partial_result;
   
            if regS = '0' then
   
                -- Approssimazione 1/12 : 1/16 + 1/64 + 1/256 + 1/1024
                sh1 := shift_right(v, 4);
                sh2 := shift_right(v, 6);
                sh3 := shift_right(v, 8);
                sh4 := shift_right(v, 10);
   
                temp := sh1 + sh2 + sh3 + sh4;
   
                if v < 0 then
                    temp := temp + 4;
                end if;
   
            else
                -- Approssimazione 1/60 : 1/64 + 1/1024
                sh2 := shift_right(v, 6);
                sh4 := shift_right(v, 10);
   
                temp := sh2 + sh4;
   
                if v < 0 then
                    temp := temp + 2;
                end if;
            end if;
   
            -- Saturazione tra -128 e 127
            if temp > to_signed(127, 19) then
                normalized <= to_signed(127, 8);
            elsif temp < to_signed(-128, 19) then
                normalized <= to_signed(-128, 8);
            else
                normalized <= resize(temp, 8);
            end if;
        end if;
    end process;


    -- processo MUX: determina o_mem_addr in base ad addr_sel, count e i_add
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
        elsif rising_edge(i_clk) then
            case addr_sel is
                when "00" => -- leggiamo k1, k2, s
                    o_mem_addr <= std_logic_vector ( unsigned(i_add) + count );
                when "01" =>-- lettura dei filtri
                    if regS = '0' then
                        o_mem_addr <= std_logic_vector ( unsigned(i_add) + 3 + count );
                    elsif regS = '1' then
                        o_mem_addr <= std_logic_vector ( unsigned(i_add) + 10 + count );
                    end if;
                when "10" => -- lettura delle k parole
                    if first_SR = '1' then -- primo riempimento
                        o_mem_addr <= std_logic_vector ( unsigned(i_add) + 17 + count );
                    elsif first_SR = '0' then
                        o_mem_addr <= curr_addr;
                    end if;
                when "11" => -- scrittura di R
                    o_mem_addr <= std_logic_vector ( unsigned(curr_addr) + unsigned(regK) - 3);
                when others =>            
            end case;
        end if;

    end process;


    -- Processo di assegnamento o_done
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            o_done <= '0';
        elsif rising_edge(i_clk) then
            if curr_state = WAIT_R and last = '1' then
                o_done <= '1';
            elsif curr_state = IDLE and i_start = '0' then
                o_done <= '0';
            end if;
        end if;
    end process;

    -- Processo di scrittura: scrive il valore normalizzato su o_mem_data e gestisce il segnale last
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            o_mem_data <= (others => '0');
            last       <= '0';
        elsif rising_edge(i_clk) then
            if last = '1' and curr_addr /= std_logic_vector(unsigned(i_add) + 17 + unsigned(regK) + 3) then  
               last <= '0';
            end if;  
            if addr_sel = "11" and can_write = '1' then
                o_mem_data <= std_logic_vector(normalized);
                if curr_addr = std_logic_vector(unsigned(i_add) + 17 + unsigned(regK) + 3) then
                    last <= '1';
                end if;
            end if;
        end if;
    end process;



end Behavioral;