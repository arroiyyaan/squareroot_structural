--sqrtk a5

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std.unsigned;

entity sqrt_a5 is
  generic (
    n : integer := 16;
    n_min1 : integer := 4 --for the size of the counter only
  );
  port(
    clk : in std_logic;
    reset : in std_logic;
    start : in std_logic;
    input : in unsigned(2*n-1 downto 0);
    done : out std_logic;
    result : out unsigned(n-1 downto 0)
  );
end sqrt_a5;

architecture a5 of sqrt_a5 is
  --control units
  type statetype is (idle, s1, s2, s3, s4, s5, s6, final);
  signal state : statetype;
  signal next_state : statetype;

  --internal signals of block X
  signal X : unsigned(2*n-1 downto 0);
  signal load_x : std_logic;
  signal sel_x : std_logic;

  --internal signals of block Z
  signal Z : unsigned(2*n-1 downto 0);
  signal load_z : std_logic;
  signal init_z : std_logic;
  signal sel_z : std_logic;

  --internal signals of block V
  signal V : unsigned(2*n-1 downto 0);
  signal load_v : std_logic;
  signal init_v : std_logic;

  --internal signals of block counter
  signal counter : unsigned(n_min1 downto 0);
  signal init_counter : std_logic;
  signal load_count : std_logic;

  --internal signals of combinatorial adder
  signal a : unsigned(2*n-1 downto 0);
  signal b : unsigned(2*n-1 downto 0);
  signal adder : signed(2*n-1 downto 0);
  type statetype1 is (select_ZV, select_NZ, select_counter);
  signal state_adder_selection : statetype1;
  signal sel_add_sub : std_logic;

  --internal flag signal
  signal done_flag : std_logic;

begin

  --main process - controlling each block
  p_sqrt : process(clk, reset)
  begin
    if (reset = '1') then
      state <= idle;
    elsif (rising_edge(clk)) then
      state <= next_state;

      --block counter
      if(load_count = '1') then
        counter <= unsigned(resize(adder, counter'length));
      elsif(init_counter = '1') then
        -- counter <= to_unsigned(2*n_min1-2, counter'length);
        counter <= to_unsigned(n, counter'length);
      else
        counter <= counter;
      end if;

      --block X
      if(load_x = '1') then
        if(sel_x = '1') then
          X <= input;
        else
          X <= unsigned(adder);
        end if;
      else
        X <= X;
      end if;

      --block Z
      if(load_z = '1') then
        if(sel_z = '1') then
          Z <= shift_right(Z, 1);
        else
          Z <= unsigned(adder);
        end if;
      elsif(init_z = '1') then
        Z <= (others => '0');
      else
        Z <= Z;
      end if;

      --block V
      if(load_v = '1') then
        V <= shift_right(V, 2);
      elsif(init_v = '1') then
        -- V <= (2*n-2 => '1', others => '0');
        V <= to_unsigned(2**(2*n-2), V'length);
      else
        V <= V;
      end if;

    end if;
  end process;

  -- combinatorial block adder
  adder <= signed(a) + signed(b) when sel_add_sub = '1' else signed(a) - signed(b);
  a <= Z when state_adder_selection = select_ZV else
    X when state_adder_selection = select_NZ else
    resize(counter, a'length) ;
  b <= V when state_adder_selection = select_ZV else
    Z when state_adder_selection = select_NZ else
    to_unsigned(1, b'length) ;

  --state process - control the signals flow and state transition
  p_state : process(state, start)
  begin
    case state is
      when idle =>
        --operating addition/subtraction
        state_adder_selection <= select_NZ; --aux
        sel_add_sub <= '0'; --aux

        --counter
        init_counter <= '1';
        load_count <= '0';

        --X
        load_x <= '1';
        sel_x <= '1';

        --Z
        init_z <= '1';
        load_z <= '0';
        sel_z <= '0';

        --V
        init_v <= '1';
        load_v <= '0';

        done_flag <= '0';

        if (start = '1') then
          next_state <= s1;
        else
          next_state <= idle;
        end if;


      when s1 =>
        --operating addition/subtraction
        state_adder_selection <= select_counter; --choosing counter operation
        sel_add_sub <= '0'; --performing subtraction

        --counter
        init_counter <= '0';
        load_count <= '1';

        --X
        load_x <= '0';
        sel_x <= '0';

        --Z
        init_z <= '0';
        load_z <= '0';
        sel_z <= '0';

        --V
        init_v <= '0';
        load_v <= '0';

        done_flag <= '0';

        --transition of state
        next_state <= s2;

      when s2 =>
        --operating addition/subtraction
        state_adder_selection <= select_ZV; --chossing Z and V operation
        sel_add_sub <= '1'; --performing addition

        --counter
        init_counter <= '0';
        load_count <= '0';

        --X
        load_x <= '0';
        sel_x <= '0';

        --Z
        init_z <= '0';
        load_z <= '1';
        sel_z <= '0';

        --V
        init_v <= '0';
        load_v <= '0';

        done_flag <= '0';

        next_state <= s3;

      when s3 =>
        --operating addition/subtraction
        state_adder_selection <= select_NZ; --choosing N and Z operation
        sel_add_sub <= '0'; --performing subtraction

        --counter
        init_counter <= '0';
        load_count <= '0';

        --X
        load_x <= '0';
        sel_x <= '0';

        --Z
        init_z <= '0';
        load_z <= '0';
        sel_z <= '0';

        --V
        init_v <= '0';
        load_v <= '0';

        done_flag <= '0';

        --transtition of state
        next_state <= s4;


      when s4 =>
        --operating addition/subtraction
        state_adder_selection <= select_counter; --aux
        sel_add_sub <= '0'; --aux

        --checking N-Z
        if(adder >= 0) then
          --counter
          init_counter <= '0';
          load_count <= '0';

          --X
          load_x <= '1';
          sel_x <= '0'; --loading from the previous N-Z

          --Z
          init_z <= '0';
          load_z <= '0';
          sel_z <= '0';

          --V
          init_v <= '0';
          load_v <= '0';

          next_state <= s5;
        else
          --operating addition/subtraction
          state_adder_selection <= select_ZV; --choosing Z and V operation
          sel_add_sub <= '0'; --subtraction

          --counter
          init_counter <= '0';
          load_count <= '0';

          --X
          load_x <= '0';
          sel_x <= '0';

          --Z
          init_z <= '0';
          load_z <= '1';
          sel_z <= '0';

          --V
          init_v <= '0';
          load_v <= '0';

          next_state <= s6;
        end if;

        done_flag <= '0';

      when s5 =>
        --operating addition/subtraction
        state_adder_selection <= select_ZV; --choosing Z and V operation
        sel_add_sub <= '1'; --performing addition

        --counter
        init_counter <= '0';
        load_count <= '0';

        --X
        load_x <= '0';
        sel_x <= '0';

        --Z
        init_z <= '0';
        load_z <= '1';
        sel_z <= '0';

        --V
        init_v <= '0';
        load_v <= '0';

        done_flag <= '0';

        next_state <= s6;

      when s6 =>
        --operating addition/subtraction
        state_adder_selection <= select_counter; --auxiliary
        sel_add_sub <= '0'; --auxiliary

        --counter
        init_counter <= '0';
        load_count <= '0';

        --X
        load_x <= '0';
        sel_x <= '0';

        --Z
        init_z <= '0';
        load_z <= '1';
        sel_z <= '1';

        --V
        init_v<= '0';
        load_v <= '1';

        done_flag <= '0';

        if (counter = 0) then
          next_state <= final;
        else
          next_state <= s1;
        end if;

      when final =>
        done_flag <= '1';

        --operating addition/subtraction
        state_adder_selection <= select_NZ; --auxiliary
        sel_add_sub <= '0'; --auxiliary

       --counter
        init_counter <= '0';
        load_count <= '0';

        --X
        load_x <= '0';
        sel_x <= '0';

        --Z
        init_z <= '0';
        load_z <= '0';
        sel_z <= '0';

        --V
        init_v <= '0';
        load_v <= '0';


        if (start = '0') then
  			     next_state <= idle;
  		  else
  			     next_state <= final;
  		  end if;

    end case;
  end process;

  -- done_flag <= '1';
  result <= resize(unsigned(Z), result'length);
  done <= done_flag;


end architecture;
