module multitoken_craft::erc1155_craft_formula {
    
    use sui::vec_map::{Self,VecMap};
    use std::vector;

    const EParameterDimensionMismatch: u64 = 1;

    /// struct that define craft formula.
    struct CraftFormula has store {
        
        //token id and amount for craft inputs.
        input_items : VecMap<u64,u64>,

        //token id and amount for craft outputs.
        output_items : VecMap<u64,u64>,
    }

    //New empty craft formula.
    public fun empty(): CraftFormula {
        CraftFormula{
            input_items : vec_map::empty(),
            output_items : vec_map::empty()
        }
    }
    public fun new_with_map(inputs: VecMap<u64,u64>,outputs: VecMap<u64,u64>): CraftFormula {
        CraftFormula{
            input_items : inputs,
            output_items : outputs
        }
    }
    public fun new_with_vec(in_token_ids:& vector<u64>,in_amounts:& vector<u64>,out_token_ids:& vector<u64>,out_amounts:& vector<u64>): CraftFormula {
        let formula = empty();
        initial_input_items(&mut formula,in_token_ids,in_amounts);
        initial_input_items(&mut formula,out_token_ids,out_amounts);

        (formula)
    }
    public fun initial_input_items(self:&mut CraftFormula,in_token_ids:& vector<u64>,in_amounts:& vector<u64>){
        assert!(vector::length(in_token_ids) == vector::length(in_amounts),EParameterDimensionMismatch);
        let ii = 0;
        let input_count = vector::length(in_token_ids);
        while(ii < input_count){
            let _id = vector::borrow(in_token_ids,ii);
            let _amount = vector::borrow(in_amounts,ii);
            vec_map::insert(&mut self.input_items,*_id,*_amount);
            ii = ii + 1;
        };
    }
    public fun initial_output_items(self:&mut CraftFormula,out_token_ids:& vector<u64>,out_amounts:& vector<u64>){
        
        assert!(vector::length(out_token_ids) == vector::length(out_amounts),EParameterDimensionMismatch);
        let oi = 0;
        let output_count = vector::length(out_token_ids);
        while(oi < output_count){
            let _id = vector::borrow(out_token_ids,oi);
            let _amount = vector::borrow(out_amounts,oi);
            vec_map::insert(&mut self.output_items,*_id,*_amount);
            oi = oi + 1;
        };
    }
    
    public fun update_input_item(self:&mut CraftFormula,token_id : u64,amount : u64){
        if(vec_map::contains(&self.input_items,&token_id)){
            if(amount > 0){
               let _amount = vec_map::get_mut(&mut self.input_items,&token_id);
               (*_amount) = amount;
            }
            else{
                 vec_map::remove(&mut self.input_items,&token_id);
            };
        }
        else{
            if(amount > 0){
                vec_map::insert(&mut self.input_items,token_id,amount);
            };
        }
    }
    public fun remove_input_item(self:&mut CraftFormula,token_id : u64){
        if(vec_map::contains(&self.input_items,&token_id)){
            vec_map::remove(&mut self.input_items,&token_id);
        }
    }
    public fun update_output_item(self:&mut CraftFormula,token_id : u64,amount : u64){
        if(vec_map::contains(&self.output_items,&token_id)){
            if(amount > 0){
               let _amount = vec_map::get_mut(&mut self.output_items,&token_id);
               (*_amount) = amount;
            }
            else{
                 vec_map::remove(&mut self.output_items,&token_id);
            };
        }
        else{
            if(amount > 0){
                vec_map::insert(&mut self.output_items,token_id,amount);
            };
        }
    }
    public fun remove_output_item(self:&mut CraftFormula,token_id : u64){
        if(vec_map::contains(&self.output_items,&token_id)){
            vec_map::remove(&mut self.output_items,&token_id);
        }
    }

    public fun update_input_items(self:&mut CraftFormula,token_ids :&vector<u64>,amounts :&vector<u64>){
        assert!(vector::length(token_ids) == vector::length(amounts),EParameterDimensionMismatch);
        let ii = 0;
        let input_count = vector::length(token_ids);
        while(ii < input_count){
            let _id = vector::borrow(token_ids,ii);
            let _amount = vector::borrow(amounts,ii);
            update_input_item(self,*_id,*_amount);
            ii = ii + 1;
        };
    }
    public fun update_output_items(self:&mut CraftFormula,token_ids:& vector<u64>,amounts:& vector<u64>){
        
        assert!(vector::length(token_ids) == vector::length(amounts),EParameterDimensionMismatch);
        let oi = 0;
        let output_count = vector::length(token_ids);
        while(oi < output_count){
            let _id = vector::borrow(token_ids,oi);
            let _amount = vector::borrow(amounts,oi);
            update_output_item(self,*_id,*_amount);
            oi = oi + 1;
        };
    }
    public fun remove_input_items(self:&mut CraftFormula,token_ids :&vector<u64>){
        let ii = 0;
        let input_count = vector::length(token_ids);
        while(ii < input_count){
            let _id = vector::borrow(token_ids,ii);
            remove_input_item(self,*_id);
            ii = ii + 1;
        };
    }
    public fun remove_output_items(self:&mut CraftFormula,token_ids :&vector<u64>){
        let ii = 0;
        let input_count = vector::length(token_ids);
        while(ii < input_count){
            let _id = vector::borrow(token_ids,ii);
            remove_output_item(self,*_id);
            ii = ii + 1;
        };
    }

    public fun get_input_count(self:&CraftFormula) : u64{
        vec_map::size(&self.input_items)
    }
    public fun get_output_count(self:&CraftFormula) : u64{
        vec_map::size(&self.output_items)
    }
    public fun get_inputs(self:&CraftFormula) : &VecMap<u64,u64>{
        &self.input_items
    }
    public fun get_outputs(self:&CraftFormula) : &VecMap<u64,u64>{
        &self.output_items
    }
    public fun get_input_token_ids(self:&CraftFormula) : vector<u64>{
        let token_ids = vector::empty();
        let ii = 0;
        let input_count = vec_map::size(&self.input_items);
        while(ii < input_count){
            let (token_id,_amount) = vec_map::get_entry_by_idx<u64,u64>(&self.input_items,ii);
            vector::push_back(&mut token_ids,*token_id);
            ii = ii + 1;
        };
        (token_ids)
    }
    public fun get_output_token_ids(self:&CraftFormula) : vector<u64>{
        let token_ids = vector::empty();
        let ii = 0;
        let output_count = vec_map::size(&self.output_items);
        while(ii < output_count){
            let (token_id,_amount) = vec_map::get_entry_by_idx<u64,u64>(&self.output_items,ii);
            vector::push_back(&mut token_ids,*token_id);
            ii = ii + 1;
        };
        (token_ids)
    }
    public fun get_input_amount(self:&CraftFormula,token_id : u64) : u64{
        if(vec_map::contains(&self.input_items,&token_id))
            return *(vec_map::get(&self.input_items,&token_id));
        return 0    
    }
    public fun get_output_amount(self:&CraftFormula,token_id : u64) : u64{
        if(vec_map::contains(&self.output_items,&token_id))
            return *(vec_map::get(&self.output_items,&token_id));
        return 0    
    }
}