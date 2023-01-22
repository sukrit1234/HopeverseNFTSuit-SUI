module multitoken_forge::erc1155_forge_formula {

    /// Many input amount to 1 output.
    struct ForgeFormula has store  {
        
        input_token_id : u64,
        input_token_amount : u64,

        output_token_id : u64,
    }

    public fun new(in_token_id: u64,in_amount: u64,out_token_id:u64): ForgeFormula {
        ForgeFormula{
            input_token_id : in_token_id,
            input_token_amount : in_amount,
            output_token_id : out_token_id,
        }
    }
    public fun empty(): ForgeFormula {
        ForgeFormula{
            input_token_id : 0,
            input_token_amount : 0,
            output_token_id : 0,
        }
    }
    public fun update_input(self:&mut ForgeFormula,token_id : u64,amount : u64){
        self.input_token_id = token_id;
        self.input_token_amount = amount;
    }
    public fun update_output(self:&mut ForgeFormula,token_id : u64){
        self.output_token_id = token_id;
    }
    public fun input_token_id(self:&ForgeFormula) : u64{
        self.input_token_id
    }
    public fun input_amount(self:&ForgeFormula) : u64{
        self.input_token_amount
    }
    public fun output_token_id(self:&ForgeFormula) : u64 {
        self.output_token_id
    }
}