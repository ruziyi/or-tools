local find = string.find
local sub = string.sub
local insert = table.insert

local _M = {}
function _M.table_is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

function _M.unescape(s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function (h)
        return string.char(tonumber(h, 16))
       end)
    return s
end

function _M.explode(str, delimeter)
    local res = {}
    --定义初始位置
    local start, start_pos, end_pos = 1, 1, 1
    --循环查找字符，每次往后移动一个位置
    while true do
        start_pos, end_pos = find(str, delimeter, start, true)
        if not start_pos then
            break
        end
        --找到字符后通过字符切割将内容保存至table
        insert(res, sub(str, start, start_pos - 1))
        start = end_pos + 1
    end
    --别忘了循环结束时还有末尾的内容要保存进来
    insert(res, sub(str,start))
    return res
end

function _M.get_post_data ()
    local args = {}
    local file_args = {}
    local receive_headers = ngx.req.get_headers()
    ngx.req.read_body()
    if string.sub(receive_headers["content-type"],1,20) == "multipart/form-data;" then
        local body_data = ngx.req.get_body_data()
        local error_code, error_msg
        if not body_data then
            local datafile = ngx.req.get_body_file()
            if not datafile then
                error_code = 1
                error_msg = "no request body found"
            else
                local fh, err = io.open(datafile, "r")
                if not fh then
                    error_code = 2
                    error_msg = "failed to open " .. tostring(datafile) .. "for reading: " .. tostring(err)
                else
                    fh:seek("set")
                    body_data = fh:read("*a")
                    fh:close()
                    if body_data == "" then
                        error_code = 3
                        error_msg = "request body is empty"
                    end
                end
            end

            if error_msg then
                ngx.log(ngx.ERR,error_msg)
            end
        end
        local new_body_data = {}
        --确保取到请求体的数据
        if not error_code then
            local boundary = "--" .. string.sub(receive_headers["content-type"],31)
            local body_data_table = _M.explode(tostring(body_data),boundary)
            local first_string = table.remove(body_data_table,1)
            local last_string = table.remove(body_data_table)
            for i,v in ipairs(body_data_table) do
                local start_pos,end_pos,capture,capture2 = string.find(v,'Content%-Disposition: form%-data; name="(.+)"; filename="(.*)"')
                if not start_pos then
                    local t = _M.explode(v,"\r\n\r\n")
                    local temp_param_name = string.sub(t[1],41,-2)
                    local temp_param_value = string.sub(t[2],1,-3)
                    args[temp_param_name] = temp_param_value
                else--文件类型的参数，capture是参数名称，capture2是文件名
                    file_args[capture] = capture2
                    table.insert(new_body_data,v)
                end
            end
            table.insert(new_body_data,1,first_string)
            table.insert(new_body_data,last_string)
            body_data = table.concat(new_body_data,boundary)--body_data可是符合http协议的请求体，不是普通的字符串
        end
    else
        args = ngx.req.get_post_args()
    end
    return args
end

function _M.get_client_ip()
    local CLIENT_IP = ngx.req.get_headers()["X_real_ip"]
    if CLIENT_IP == nil then
        CLIENT_IP = ngx.req.get_headers()["X_Forwarded_For"]
    end
    if CLIENT_IP == nil then
        CLIENT_IP  = ngx.var.remote_addr
    end
    if CLIENT_IP == nil then
        CLIENT_IP  = ""
    end
    return CLIENT_IP
end

-- Get the client user agent
function _M.get_user_agent()
    local USER_AGENT = ngx.var.http_user_agent
    if USER_AGENT == nil then
        USER_AGENT = "unknown"
    end
    return USER_AGENT
end
-- get server's host
function _M.get_server_host()
    local host = ngx.req.get_headers()["Host"]
    return host
end

return _M

