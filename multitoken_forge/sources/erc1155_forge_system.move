module multitoken_forge::erc1155_forge_system {

    use std::string;
    use sui::address;
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self,TxContext};
    use sui::vec_map::{Self,VecMap};
    use erc1155::collection::{Self,MultiToken,Collection,CollectionCapability};
    use multitoken_forge::erc1155_forge_formula::{Self,ForgeFormula};

    const EForgeCollectionUndefined: u64 = 4;

    const EParameterDimensionMismatch: u64 = 5;

    const ENotWhitelisted: u64 = 9;

    const ETemplateUndefined: u64 = 10;

    const EInsufficientInputs: u64 = 11;

    const EInsufficientFund: u64 = 11;

    const ETemplateNotEnabled: u64 = 12;
    
    const EInputTokenUndefined: u64 = 13;

    const EOutputTokenUndefined: u64 = 14;

    const EZeroForgeCount: u64 = 15;

    const EZeroInputAmount: u64 = 16;

    const EZeroOutputAmount: u64 = 17;

    const ESameMerchantAddress: u64 = 17;

    struct ForgeTemplateInfo<phantom Currency> has key, store {
        id: UID,
        name: string::String,
        description : string::String, 
        collection_id : ID,
        operation_price : u64,
        formula : ForgeFormula,
        enabled : bool
    }
    struct ForgeCollection<phantom Currency> has key, store {
        id: UID,
        running_no : u64,
        collection_id : ID,
        templates : VecMap<u64,ForgeTemplateInfo<Currency>>,
        merchant_address : address
    }

    struct ForgeCollectionCreated has copy, drop {
        id : ID,
        collection_id : ID
    }
    struct ForgeCollectionRemoved has copy, drop {
        id : ID,
        collection_id : ID
    }
    struct ForgeTemplateCreated has copy, drop {
        id : ID,
        template_id : u64
    }
    public entry fun create_forge_collection<T:drop,Currency>(gm : &CollectionCapability<T>,ctx: &mut TxContext){
        
        let collection_id = collection::get_collection_id_from_owner(gm);
        let forgeSystem = ForgeCollection<Currency> {
            id: object::new(ctx), 
            running_no : 0,
            collection_id : collection_id, 
            templates : vec_map::empty(),
            merchant_address : tx_context::sender(ctx)
        };

        let forgesys_id = object::uid_to_inner(&forgeSystem.id);
        transfer::share_object(forgeSystem);

        event::emit(ForgeCollectionCreated {id : forgesys_id,collection_id : collection_id});
    }
    //Remove whitelist shared objet (in not real remove just cut reference make it invalid)
    public entry fun unuse_craft_collection<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>){
       
        let collection_id = collection::get_collection_id_from_owner(gm);
        assert!(collection_id == forgecol.collection_id,EForgeCollectionUndefined);
       
        let forge_id = object::uid_to_inner(&forgecol.id);
        event::emit(ForgeCollectionRemoved {id : forge_id,collection_id});
        forgecol.collection_id = object::id_from_address(address::from_u256(0));
    }

    fun define_forge_template_internal<Currency>(forgecol :&mut ForgeCollection<Currency>,name : vector<u8>,description : vector<u8>,price : u64,ctx: &mut TxContext) : u64 {
        let next_id = forgecol.running_no + 1;
        let template = ForgeTemplateInfo{
            id : object::new(ctx),
            name: string::utf8(name),
            description : string::utf8(description),
            collection_id : forgecol.collection_id,
            operation_price : price,
            formula : erc1155_forge_formula::empty(),
            enabled : true
        };
        forgecol.running_no = next_id;
        vec_map::insert(&mut forgecol.templates,next_id,template);
        
        (next_id)
    }

    public entry fun change_merchant<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,new_merchant_address : address){
        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(forgecol.merchant_address != new_merchant_address,ESameMerchantAddress);
        forgecol.merchant_address = new_merchant_address;
    }

    public entry fun define_forge_template<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,name : vector<u8>,description : vector<u8>,
            price : u64,input_token_id : u64,input_token_amount : u64,output_token_id : u64,ctx: &mut TxContext){

        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        let template_id = define_forge_template_internal(forgecol,name,description,price,ctx);
        let template = vec_map::get_mut(&mut forgecol.templates,&template_id);

        erc1155_forge_formula::update_input(&mut template.formula,input_token_id,input_token_amount);
        erc1155_forge_formula::update_output(&mut template.formula,output_token_id);

        let tplobj_id = object::uid_to_inner(&template.id);
        event::emit(ForgeTemplateCreated {id : tplobj_id,template_id : template_id})

    }

    public entry fun define_empty_forge_template<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,name : vector<u8>,description : vector<u8>,price : u64,ctx: &mut TxContext){
        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        let template_id = define_forge_template_internal(forgecol,name,description,price,ctx);
        let template = vec_map::get(&forgecol.templates,&template_id);

        let tplobj_id = object::uid_to_inner(&template.id);
        event::emit(ForgeTemplateCreated {id : tplobj_id,template_id : template_id})
    }
    public entry fun set_forge_template_enabled<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,template_id : u64,enabled : bool){

        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);

        let forge_template = vec_map::get_mut(&mut forgecol.templates,&template_id);
        forge_template.enabled = enabled;
    }
    public entry fun update_forge_template_name<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,template_id : u64,name : vector<u8>){

        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);

        let forge_template = vec_map::get_mut(&mut forgecol.templates,&template_id);
        forge_template.name = string::utf8(name);
    }
    public entry fun update_forge_template_description<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,template_id : u64,description : vector<u8>){
        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);

        let forge_template = vec_map::get_mut(&mut forgecol.templates,&template_id);
        forge_template.description = string::utf8(description);
    }
    public entry fun update_forge_template_price<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,template_id : u64,price : u64){
        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);

        let forge_template = vec_map::get_mut(&mut forgecol.templates,&template_id);
        forge_template.operation_price = price;
    }

    public entry fun update_input<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,template_id : u64,token_id : u64,amount : u64){
        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);
        let forge_template = vec_map::get_mut(&mut forgecol.templates,&template_id);
        erc1155_forge_formula::update_input(&mut forge_template.formula,token_id,amount);
    }
    public entry fun update_output<T:drop,Currency>(gm : &CollectionCapability<T>,forgecol :&mut ForgeCollection<Currency>,template_id : u64,token_id : u64){
        assert!(is_valid_forgecollection(gm,forgecol),EForgeCollectionUndefined);
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);
        let forge_template = vec_map::get_mut(&mut forgecol.templates,&template_id);
        erc1155_forge_formula::update_output(&mut forge_template.formula,token_id);
    }

    public fun is_definded<Currency>(forgecol : &ForgeCollection<Currency>,template_id : u64) : bool {
        vec_map::contains(&forgecol.templates,&template_id)
    }
    public fun is_valid_forgecollection<T:drop,Currency>(gm : &CollectionCapability<T>,forgetcol : &ForgeCollection<Currency>) : bool {   
        let collection_id = collection::get_collection_id_from_owner(gm);
        forgetcol.collection_id == collection_id
    }
    public fun forge<T:drop,Currency>(collection : &mut Collection<T>,forgecol : &ForgeCollection<Currency>,template_id : u64,album :&mut MultiToken<T>,coin : &mut Coin<Currency>,apply_count : u64,ctx: &mut TxContext){

        //Check apply count is valid ?.
        assert!(apply_count > 0,EZeroForgeCount);

        //Check template undefined ?
        assert!(is_definded(forgecol,template_id),ETemplateUndefined);

        //Check template enabled ?        
        let template = vec_map::get(&forgecol.templates,&template_id);
        assert!(template.enabled,ETemplateNotEnabled);

        //Check input token id defined. ?        
        let input_token_id = erc1155_forge_formula::input_token_id(&template.formula);
        assert!(collection::is_definded(collection,input_token_id),EInputTokenUndefined);

        //Check input amount is valid (>=1)
        let input_token_amt = erc1155_forge_formula::input_amount(&template.formula);
        assert!(input_token_amt > 0,EZeroInputAmount);

        //Check output token id defined. ?        
        let output_token_id = erc1155_forge_formula::output_token_id(&template.formula);
        assert!(collection::is_definded(collection,output_token_id),EOutputTokenUndefined);

        //CHeck total input amount to use against available.
        let total_input_amount = apply_count*input_token_amt;
        let current_amount = collection::value(album,input_token_id);
        assert!(current_amount >= total_input_amount,EInsufficientInputs);

        let total_fee = template.operation_price*apply_count;
        let current_coin_balance = coin::value(coin);
        assert!(current_coin_balance >= total_fee,EInsufficientFund);

        //Burn inputs.
        collection::burn_amount(collection,album,input_token_id,total_input_amount);
        //Mint output.
        collection::mint_amount(collection,album,output_token_id,apply_count);

        //Conduct operation fee and send to merchant.
        let operation_fee_coin = coin::split(coin,total_fee,ctx);
        transfer::transfer(operation_fee_coin,forgecol.merchant_address);
    }
}