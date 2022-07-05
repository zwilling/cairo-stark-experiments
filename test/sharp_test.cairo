%builtins output

func main(output_ptr : felt*) -> (output_ptr : felt*):
    alloc_locals
    local x
    %{ ids.x = program_input['x'] %}
    assert [output_ptr] = x * x
    return (output_ptr=output_ptr + 1)
end