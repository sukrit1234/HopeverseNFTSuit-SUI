
module erc721::erc721_metadata {
    use std::ascii;
    use sui::url::{Self, Url};
    use std::string;

    struct ERC721Metadata has store {
        /// The token id associated with the source contract on Ethereum
        token_id: TokenID,
        /// A descriptive name for a collection of NFTs in this contract.
        /// This corresponds to the `name()` method in the
        /// ERC721Metadata interface in EIP-721.
        name: string::String,
        /// A distinct Uniform Resource Identifier (URI) for a given asset.
        /// This corresponds to the `tokenURI()` method in the ERC721Metadata
        /// interface in EIP-721.
        token_uri: Url,
    }

    struct TokenID has store, copy {
        id: u64,
    }

    public fun new(token_id: TokenID, name: vector<u8>, token_uri: vector<u8>): ERC721Metadata {
        let uri_str = ascii::string(token_uri);
        ERC721Metadata {
            token_id,
            name: string::utf8(name),
            token_uri: url::new_unsafe(uri_str),
        }
    }

    public fun new_token_id(id: u64): TokenID {
        TokenID { id }
    }

    public fun token_id(self: &ERC721Metadata): &TokenID {
        &self.token_id
    }

    public fun token_uri(self: &ERC721Metadata): &Url {
        &self.token_uri
    }
    public fun name(self: &ERC721Metadata): &string::String {
        &self.name
    }

    public fun update_token_uri(self: &mut ERC721Metadata, token_uri: vector<u8>){ 
       let uri_str = ascii::string(token_uri);
       self.token_uri = url::new_unsafe(uri_str)
    }
    public fun update_name(self: &mut ERC721Metadata, name: vector<u8>){
        self.name = string::utf8(name)
    }
}