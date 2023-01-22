// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module erc1155::erc1155_metadata {
    use std::ascii;
    use sui::url::{Self, Url};
    use std::string;

    // TODO: add symbol()?
    /// A wrapper type for the ERC1155 metadata standard https://eips.ethereum.org/EIPS/eip-1155
    struct ERC1155Metadata has store {
        
        /// The token id associated with the source contract on Ethereum
        token_id: TokenID,
        
        /// A descriptive name for a collection of NFTs in this contract.
        /// This corresponds to the `name()` method in the
        /// ERC1155Metadata interface in EIP-1155.
        name: string::String,

        /// A distinct Uniform Resource Identifier (URI) for a given asset.
        /// This corresponds to the `tokenURI()` method in the ERC1155Metadata
        /// interface in EIP-1155.
        token_uri: Url,

        //Max supply to token.
        max_supply : u64,
    }

    // TODO: replace u64 with u256 once the latter is supported
    // <https://github.com/MystenLabs/fastnft/issues/618>
    /// An ERC1155 token ID
    struct TokenID has store, copy {
        id: u64,
    }

    /// Construct a new ERC1155Metadata from the given inputs. Does not perform any validation
    /// on `token_uri` or `name`
    public fun new(token_id: TokenID, name: vector<u8>, token_uri: vector<u8>,max_supply:u64): ERC1155Metadata {
        let uri_str = ascii::string(token_uri);
        ERC1155Metadata {
            token_id,
            name: string::utf8(name),
            token_uri: url::new_unsafe(uri_str),
            max_supply
        }
    }
    public fun new_token_id(id: u64): TokenID {
        TokenID { id }
    }

    public fun get_token_id(self: &ERC1155Metadata): &TokenID {
        &self.token_id
    }
    public fun get_token_uri(self: &ERC1155Metadata): &Url {
        &self.token_uri
    }
    public fun get_name(self: &ERC1155Metadata): &string::String {
        &self.name
    }
     public fun get_max_supply(self: &ERC1155Metadata): u64 {
        self.max_supply
    }

    public fun update_token_uri(self: &mut ERC1155Metadata, token_uri: vector<u8>){ 
       let uri_str = ascii::string(token_uri);
       self.token_uri = url::new_unsafe(uri_str)
    }
    public fun update_name(self: &mut ERC1155Metadata, name: vector<u8>){
        self.name = string::utf8(name)
    }
    public fun update_max_supply(self: &mut ERC1155Metadata,max_supply : u64) {
        self.max_supply =  max_supply;
    }
}