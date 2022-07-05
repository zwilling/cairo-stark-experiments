%builtins output pedersen range_check

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.serialize import serialize_word


const MERKLE_TREE_DEPTH = 3

func computeMerkleRootOfProof{pedersen_ptr : HashBuiltin*}(
    leaf : felt,
    path_elements : felt*, # hashes of neighboring nodes on the merkle path
    path_indices : felt*, # 0 for leaf is on the left, 1 for right
    depth : felt, # depth of the tree (decremented with recursion)
) -> (root : felt):
    if depth == 0:
        return (root=leaf)
    end
    
    let (next_node) = hash2{hash_ptr=pedersen_ptr}(leaf, path_elements[0])

    # recursive implementation as suggested in the docs
    let (root) = computeMerkleRootOfProof{
        pedersen_ptr = pedersen_ptr
    }(
        leaf = next_node,
        path_elements = path_elements + 1,
        path_indices = path_indices + 1,
        depth = depth - 1,
    )
    return (root=root)
end

func main{
    output_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}() -> ():
    alloc_locals

    # public inputs, made public by returning them later
    local balance_threshold
    local address_hash
    
    # private inputs
    local balance
    local address
    local address_nonce
    local address_storage_root
    local address_code_hash
    local merkle_path_elements : felt*
    local merkle_path_indices : felt*


    # hint for hiding assignment of private inputs
    # also the only place where we can read input
    %{
        ids.balance = program_input['balance']
        ids.balance_threshold = program_input['balanceThreshold']
        ids.address = program_input['address']
        ids.address_nonce = program_input['addressNonce']
        ids.address_storage_root = program_input['addressStorageRoot']
        ids.address_code_hash = program_input['addressCodeHash']

        element_inputs = program_input['merklePathElements']
        ids.merkle_path_elements = merkle_path_elements = segments.add()
        for i, val in enumerate(element_inputs):
            memory[merkle_path_elements + i] = val

        indices_inputs = program_input['merklePathIndices']
        ids.merkle_path_indices = merkle_path_indices = segments.add()
        for i, val in enumerate(indices_inputs):
            memory[merkle_path_indices + i] = val
    %}

    # verify address hash (using pedersen hash)
    let (address_ptr) = alloc()
    assert [address_ptr] = 1 # set array length
    assert [address_ptr + 1] = address
    let (address_hash) = hash_chain{hash_ptr=pedersen_ptr}(address_ptr)
    
    # verify balance threshold
    # ensure outside that balances are inside the 'mod p' group
    assert_le(balance_threshold, balance)

    # verify address data validity by constructing the merkle leaf
    let (utxo_data) = alloc()
    assert [utxo_data] = 5 # set array length
    assert [utxo_data + 1] = address_nonce
    assert [utxo_data + 2] = balance
    assert [utxo_data + 3] = address_storage_root
    assert [utxo_data + 4] = address_code_hash
    assert [utxo_data + 5] = address
    let (merkle_leaf) = hash_chain{hash_ptr=pedersen_ptr}(utxo_data)

    let (merkle_root) = computeMerkleRootOfProof{
        pedersen_ptr = pedersen_ptr
    }(
        leaf = merkle_leaf,
        path_elements = merkle_path_elements,
        path_indices = merkle_path_indices,
        depth = MERKLE_TREE_DEPTH,
    )

    # Write the program output.
    serialize_word(balance_threshold)
    serialize_word(address_hash)
    serialize_word(merkle_root)

    return ()
end