function main()
    if not os.exists(import("core.project.project").rootfile()) then
        -- trigger a return code != 0
        raise("")
    end
    print("hello")
end