#==============================================================================#
# AWSLambdaWrapper.jl
#
# AWS Lambda wrapper for Julia.
#
# See http://docs.aws.amazon.com/lambda/latest/dg/API_Reference.html
#
# Copyright Sam O'Connor 2014 - All rights reserved
#==============================================================================#


__precompile__()


module AWSLambdaWrapper

using JSON


# Run the lambda function...
function invoke_lambda(lambda_module::Module, event)

    for m in Vector{Symbol}(get(event,"jl_modules",[]))
        eval(Main, :(using $m))
    end

    open("/tmp/lambda_out", "w") do out

        if haskey(event, "jl_data")

            args = deserialize(Base64DecodePipe(IOBuffer(event["jl_data"])))
            b64_out = Base64EncodePipe(out)
            serialize(b64_out, lambda_module.lambda_function(args...))
            close(b64_out)

        else 
            JSON.print(out, lambda_module.lambda_function_with_event(event))
        end
    end
end



function main(lambda_module::Module)

    # Read from STDIN into buf...
    buf = UInt8[]
    while true
        chunk = readavailable(STDIN)
        append!(buf, chunk)
        @assert length(chunk) > 0

        # Wait for end of input..., then call invoke_lambda()...
        if length(buf) >  1 && buf[end-1:end] == ['\0','\n']

            input = JSON.parse(UTF8String(buf))
            empty!(buf)

            global AWS_LAMBDA_CONTEXT = input["context"]
            invoke_lambda(lambda_module, input["event"])
            
            # Signal end of output on STDOUT...
            write(STDOUT, "\0\n")
        end
    end
end


end # module AWSLambdaWrapper



#==============================================================================#
# End of file.
#==============================================================================#