#=

Autor: Adriano Bassignana Bargamo 2021
Licence: GPL 2

Exite code:
0 - regular execution
1 - The version check did not pass

Performance:
On average with a 70 mbit connection (7-8 MB / s) the ArcGIS site from a flow of 1 MB / s (8 mbit) This places a limit on the download capacity,
I don't know if it can be amplified with multiple connections, but I think not, as it is related to the IP of the machine.
The only possibility is to parallelize with more sophisticated techniques.
However if the files are large it is not necessary to increase the number of threads too much julia -t 6 can be absolutely fine in these cases.
While if smaller formats are used (series -c 0,1,2) the advantage of many threads is considerable.

Behavior of the program:
Currently it does not leave logs during some activities, eg it can be quite depressing not to see anything when starting a
download with very large images (eg 8K or 16K) especially if you use a lot of threads.
In this case all the work takes place in the background and no messages are observed.
Don't worry, the program is doing its job. However, a more effective monitor will soon be added.

----------

Execution with thread and CPU

julia -t 10 -p 2 photoscenary.jl ...

it is possible to manage multithreaded and multi CPU processes with Julia through these two options:
-t m : The maximum number of threads that can be followed simultaneously.
-p n : The number of CPUs that can be used

----------

Search LAT and LON from Airport Tower Freq Radio

    using CSV
    using CSVFiles
    using DataFrames
    using DataFramesMeta

df = CSV.File("airports.csv"; normalizenames=true, delim=" ", select=["LAT","LON","ICAO","NAME"], decimal='.')
...
CSV.Row: (LAT = -17.9318, LON = 31.0928, ICAO = "FVHA")

Search airport ID

for r in df
    if cmp(r[3],"LIME") == 0 println(r) end
end

=#

using Pkg

if VERSION < v"1.5.0"
    println("The actiual Julia is ",VERSION, " The current version is too old!\nPlease upgrade Julia to version 1.5.0 but preferably install the 1.6.x or later (exit code 500)")
    ccall(:jl_exit, Cvoid, (Int32,), 500)
elseif VERSION >= v"1.6.0"
    println("The actiual Julia is ",VERSION, " The current version is correct in order to obtain the best performances")
else
    println("The actiual Julia is ",VERSION, " The current version is correct,\nIn order to obtain the best performancesy install the 1.6.x or later version")
end


versionProgram = "0.2.6"
versionProgramDate = "Testing 20210522"

homeProgramPath = pwd()
unCompletedTiles = Dict{Int64,Int64}()

println("\nPhotoscenary.jl ver: $versionProgram date: $versionProgramDate System prerequisite test\n")


begin

    local restartIsRequestCauseUpgrade = 0

    try
        using ImageView
        using JuliaDB
    catch
        restartIsRequestCauseUpgrade = 2
    end

    try
        import ImageMagick
        using Dates
        using Unicode
        using Downloads
        using Logging
        using Distributed
        using LightXML
        using ArgParse
        using Printf
        using HTTP
        using FileIO
        using Images
        using ImageIO
        using DataFrames
        using DataFramesMeta
    catch
        if restartIsRequestCauseUpgrade == 0 restartIsRequestCauseUpgrade = 1 end
    end

    try
        if restartIsRequestCauseUpgrade >= 2
            Pkg.add("ImageView") # If this is execute is necessary to restart Julia
            Pkg.add("JuliaDB")
        end
        if restartIsRequestCauseUpgrade >= 1
            println("\nInstal the packeges necessary for photoscenary.jl execution")
            Pkg.add("Dates")
            Pkg.add("Unicode")
            Pkg.add("Downloads")
            Pkg.add("Logging")
            Pkg.add("Distributed")
            Pkg.add("LightXML")
            Pkg.add("ImageMagick")
            Pkg.add("ArgParse")
            Pkg.add("Printf")
            Pkg.add("HTTP")
            Pkg.add("FileIO")
            Pkg.add("Images")
            Pkg.add("ImageIO")
            Pkg.add("DataFrames")
            Pkg.add("DataFramesMeta")
            println("\nThe Julia system has been updated")
        end
    catch err
        println("\nProblems loading library modules, program execution will now be interrupted\nError: $err (exit code 500)")
        ccall(:jl_exit, Cvoid, (Int32,), 500)
    end

    if restartIsRequestCauseUpgrade >= 2
        println("\nThe Julia packeges and extra packeges has been updateds!\n\n\tNote: Sometimes, especially on Windows machines,\n\tafter the restart, there may be print some orrors messages,\n\tnormally there is no problem if you wait a few tens of seconds, if the system seems to stop,\n\tyou can give a CTRL-C and restart the program execution operation again.\n\tThe package management system will solve any problems in the next restart of the program.\n\nNow the program ends and a re-execution is requested (exit code 100)")
        ccall(:jl_exit, Cvoid, (Int32,), 100)
    end

end

@everywhere using SharedArrays

# Test set:
# python3 creator.py --lat 38 --lon 16 --info_only
# Bucket: {'min_lat': 38.0, 'max_lat': 38.125, 'min_lon': 16.0, 'max_lon': 16.25, 'center_lat': 38.0625, 'center_lon': 16.125}. Index: 3219456

# Lat: 38 cmd=python3 creator.py --lat "38.0000" --lon "16.0000" --info_only
# Tile 3219456 needs download
#= Testing (max 4096 x 2048)
/World_Imagery/MapServer/export?bbox=16.0,38.0,16.125,38.0625&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
/World_Imagery/MapServer/export?bbox=16.125,38.0,16.25,38.0625&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
/World_Imagery/MapServer/export?bbox=16.0,38.0625,16.125,38.125&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
/World_Imagery/MapServer/export?bbox=16.125,38.0625,16.25,38.125&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
INFO:root:Joining tiles to /home/abassign/photoscenery/Orthophotos/e010n30/e016n38/3219456.png
Bucket: {'min_lat': 38.0, 'max_lat': 38.125, 'min_lon': 16.0, 'max_lon': 16.25, 'center_lat': 38.0625, 'center_lon': 16.125}. Index: 3219456
cmd=python3 creator.py --lat "38.0000" --lon "16.0500" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.1000" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.1500" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.2000" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.2500" --info_only

Test lat 64 deg N

python3 creator.py --index 2582136
Bucket: {'min_lat': 63.875, 'max_lat': 64.0, 'min_lon': -23.0, 'max_lon': -22.5, 'center_lat': 63.9375, 'center_lon': -22.75}. Index: 2582136
INFO:root:Downloading tile=/tmp/tmp3h6qij5v from url=http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export?bbox=-23.0,63.875,-22.5,64.0&bboxSR=4326&size=8192,2048&imageSR=4326&format=png24&f=image
INFO:root:Joining tiles to /home/abassign/Scaricati/flightgear-photoscenery-master/Orthophotos/w030n60/w023n63/2582136.png

=#

m = [90, 89, 86, 83, 76, 62, 22,-22]
n = [12.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.125]


completedTile = Dict{Int64,Int64}()

tileWidth(lat) = reduce(+,map((x,y,z)->z * (abs(lat) < x) * (abs(lat) >= y),m,m[begin+1:end],n))

baseX(lat,lon) = floor(floor(lon / tileWidth(lat)) * tileWidth(lat))
x(lat,lon) = floor(Int,(lon - baseX(lat,lon)) / tileWidth(lat))
baseY(lat) = floor(lat)
y(lat) = floor(Int,(lat - baseY(lat)) * 8)

index(lat,lon) = (floor(Int,lon + 180) << 14) + floor(Int,lat + 90) << 6 + (y(lat) << 3) + x(lat,lon)

minLat(lat) = baseY(lat) + 1.0 * (y(lat) // 8)
maxLat(lat) = baseY(lat) + 1.0 * ((1 + y(lat)) // 8)

minLon(lat,lon) = baseX(lat,lon) + x(lat,lon) * tileWidth(lat)
maxLon(lat,lon) = minLon(lat,lon) + tileWidth(lat)

centerLat(lat) = minLat(lat) + (maxLat(lat) - minLat(lat)) / 2.0
centerLon(lat,lon) = minLon(lat,lon) + (maxLon(lat,lon) - minLon(lat,lon)) / 2.0

longDegOnLatitudeNm(lat) = 2 * pi * 6371.0 * 0.53996 * cosd(lat) / 360.0
longDegOnLongitudeNm() = pi * 6378.0 * 0.53996 / 180

latDegByCentralPoint(lat,lon,radius) = (
    round((lat -  mod(lat,0.125)) - (radius/longDegOnLongitudeNm()),digits=1),
    round((lon -  mod(lon,tileWidth(lat))) - (radius/longDegOnLatitudeNm(lat)),digits=1),
    round((lat - mod(lat,0.125) + 0.125) + (radius/longDegOnLongitudeNm()),digits=1),
    round((lon - mod(lon,tileWidth(lat)) + tileWidth(lat))+ (radius/longDegOnLatitudeNm(lat)),digits=1))

sizeHight(sizeWidth,lat) = Int(sizeWidth / (8 * tileWidth(lat)))

function coordFromIndex(index)
    lon = (index >> 14) - 180
    lat = ((index - ((lon + 180) << 14)) >> 6) - 90
    y = (index - (((lon + 180) << 14) + ((lat + 90) << 6))) >> 3
    x = index - ((((lon + 180) << 14) + ((lat + 90) << 6)) + (y << 3))
    return lon + (tileWidth(lat) / 2.0 + x * tileWidth(lat)) / 2.0, lat + (0.125 / 2 + y * 0.125) / 2.0, lon, lat, x, y
end

# Inizialize section

function inizializeParams()
    # Build the paramsXml
    paramsXml = nothing
    if isfile("params.xml")
        paramsXml = parse_file("params.xml")
        if "params" == lowercase(name(root(paramsXml)))
            xroot = root(paramsXml)
            ces = get_elements_by_tagname(xroot,"versioning")
            if ces != nothing && find_element(ces[1],"version") != nothing
                set_content(find_element(ces[1],"version"),versionProgram)
            end
        end
    end
    if (paramsXml == nothing)
        paramsXml = parse_string("<params><versioning><version>$versionProgram</version><autor>Adriano Bassignana</autor><year>2021</year><licence>GPL 2</licence></versioning></params>")
    end
    save_file(paramsXml,"params.xml")
end


function inizialize()
    versionFromParams = nothing
    imageMagickPath = nothing
    if isfile("params.xml")
        paramsXml = parse_file("params.xml")
        if "params" == lowercase(name(root(paramsXml)))
            xroot = root(paramsXml)
            ces = get_elements_by_tagname(xroot,"versioning")
            if ces != nothing && size(ces)[1] > 0 && find_element(ces[1],"version") != nothing
                versionFromParams = content(find_element(ces[1],"version"))
            end
            img = get_elements_by_tagname(xroot,"imageMagick")
            if img != nothing && size(img)[1] > 0 && find_element(img[1],"path") != nothing
                imageMagickPath = strip(content(find_element(img[1],"path")))
                if length(imageMagickPath) == 0 imageMagickPath = nothing end
            end
        end
    end
    if versionFromParams == nothing || versionFromParams != versionProgram
        println("\nThe program version is change old version is $versionFromParams the actual version is $versionProgram ($versionProgramDate)")
        inizializeParams()
    end
    println('\n',"Photoscenery generator by Julia compilator,\nProgram for uploading Orthophotos files\n")
    paramsXml = parse_file("params.xml")
    if "params" == lowercase(name(root(paramsXml)))
        ces = get_elements_by_tagname(root(paramsXml),"versioning")
    end
    return imageMagickPath
end


#Testing image magick
function checkImageMagick(imageMagickPath)
    imageMagickTest = nothing
    if imageMagickPath != nothing
        println("\ncheckImageMagick - is define a path for imageMagick: $imageMagickPath")
        println("In the params.xml configuration file\n")
    end
    try
        if Base.Sys.iswindows()
            imageMagickStatus = run(`magick convert -version`)
        else
            imageMagickStatus = run(`convert -version`)
        end
        if imageMagickPath == nothing
            imageMagickTest = 1
        else
            imageMagickPath = nothing
            imageMagickTest = 2
        end
    catch err
        try
            if Base.Sys.iswindows()
                imageMagickTest = 4
            elseif imageMagickPath != nothing
                imageMagickWithPathUnix = normpath(imageMagickPath * "/" * "convert")
                imageMagickStatus = run(`$imageMagickWithPathUnix -version`)
                imageMagickTest = 3
            else
                imageMagickTest = 4
            end
            imageMagickPath = nothing
            println("checkImageMagick - ImageMagic is operative!")
        catch err
            imageMagickTest = 5
        end
    end
    if imageMagickTest == 1
        println("\nImageMagic is operative!")
        return true,imageMagickPath
    elseif imageMagickTest == 2
        println("\nImageMagic is operative!")
        if Base.Sys.iswindows() == false
            println("The path is: $imageMagickPath")
            println("This path is not necessary\nI recommend removing it by editing the file: 'params.xml'\ngetting this situation:")
            println("<imageMagick>")
            println("    <path></path>")
            println("</imageMagick>")
        end
        return true,imageMagickPath
    elseif imageMagickTest == 3
        println("\nImageMagic is operative!")
        println("The path is: $imageMagickPath")
        return true,imageMagickPath
    elseif imageMagickTest == 4
        println("\nError: The program, named: 'imageMagick' for converting files into .dds format (Error code 504)\nbut has not been well installed!")
        println("It has often been verified that ImageMagick on Windows should be installed\nonly after having previously uninstalled ImageMagick.")
        println("When installing imageMagick make sure you have at least flegged the following options:")
        println("#1 [x] Add application direcory to your system path")
        println("#2 [x] Install legacy utilities (e.g. convert)")
        println("\nNow this application is stopped waiting for these issues to be fixed")
        println("It is therefore necessary to install the program ImageMagick the home page is: https://imagemagick.org/")
        println("You can install the program at this link: https://imagemagick.org/script/download.php")
        println("If you are with the Windows operating system, absolutely remember, once ImageMagick is installed, to restart the PC!")
        return false,imageMagickPath
    elseif imageMagickTest == 5
        println("\nError: The program imageMagick with the path: $imageMagickPath")
        println("was not found, check if the path was written correctly or 'imageMagick' is installed on your system.")
        return false,imageMagickPath
    end
end


# Coordinates matrix generator

function coordinateMatrixGenerator(latLL,lonLL,latUR,lonUR,systemCoordinatesIsPolar,whiteTileIndexListDict,isDebug)
    numberOfTiles = 0
    # Normalization to 0.125 deg
    latLL = latLL - mod(latLL,0.125)
    latUR = latUR - mod(latUR,0.125) + 0.125
    lonLL = lonLL - mod(lonLL,tileWidth(latLL))
    lonUR = lonUR - mod(lonUR,tileWidth(latLL)) + tileWidth(latLL)
    a = [(
            string(lon >= 0.0 ? "e" : "w", lon >= 0.0 ? @sprintf("%03d",floor(abs(lon),digits=-1)) : @sprintf("%03d",ceil(abs(lon),digits=-1)),
                lat >= 0.0 ? "n" : "s", lat >= 0.0 ? @sprintf("%02d",floor(abs(lat),digits=-1)) : @sprintf("%02d",ceil(abs(lat),digits=-1))),
            string(lon >= 0.0 ? "e" : "w", lon >= 0.0 ? @sprintf("%03d",floor(Int,abs(lon))) : @sprintf("%03d",ceil(Int,abs(lon))),
                lat >= 0.0 ? "n" : "s", lat >= 0.0 ? @sprintf("%02d",floor(Int,abs(lat))) : @sprintf("%02d",ceil(Int,abs(lat)))),
            lon,
            lat,
            lon + tileWidth(lat),
            lat + 0.125,
            floor(Int,lat*10),
            index(lat,lon),
            x(lat,lon),
            y(lat),
            tileWidth(lat)
        )
        for lat in latLL:0.125:latUR for lon in lonLL:tileWidth(lat):lonUR]
    # print data sort by tile index
    aSort = sort!(a,by = x -> x[8])
    c = nothing
    d = []
    precIndex = nothing
    counterIndex = 0
    for b in aSort
        if whiteTileIndexListDict == nothing || (whiteTileIndexListDict != nothing && haskey(whiteTileIndexListDict,b[8]))
            if precIndex == nothing || precIndex != b[8]
                if c != nothing push!(d,c) end
                c = []
                precIndex = b[8]
                counterIndex = 1
            else
                counterIndex += 1
            end
            t = (b[1],b[2],b[3],b[5],b[4],b[6],b[8],counterIndex,b[11],0)
            push!(c,t)
            push!(c,0)
            numberOfTiles += 1
            if isDebug > 1 println("Tile id: ",t[7]," coordinates: ",t[1]," ",t[2],
                " | lon: ",@sprintf("%03.6f ",t[3]),
                @sprintf("%03.6f ",t[4]),
                "lat: ",@sprintf("%03.6f ",t[5]),
                @sprintf("%03.6f ",t[6])," | Counter: ",t[8]," Width: ",@sprintf("%03.6f",t[9])) end
        end
    end
    if c != nothing
        push!(d,c)
    end

    if isDebug > 0
        println("\n----------")
        println("CoordinateMatrix generator")
        println("latLL: ",latLL," lonLL ",lonLL," latUR: ",latUR," lonUR ",lonUR,'\n')
        println("Number of tiles to process: $numberOfTiles")
        println("----------\n")
    end

    return d,numberOfTiles
end


function fileWithRootHomePath(fileName)
    return normpath(homeProgramPath * "/" * fileName)
end


function setPath(root,pathLiv1,pathLiv2)
    rootDirectoryIsOk = false
    path = root * "/" * pathLiv1 * "/" * pathLiv2
    try
        rootDirFiles = mkpath(path)
        rootDirectoryIsOk = true
        return path
    catch err
        println("The $root directory is inexistent, the directory will be is created")
        return nothing
    end
end


function getDDSSize(imageWithPathTypeDDS)
    if isfile(imageWithPathTypeDDS)
        try
            if Base.Sys.iswindows()
                identify = read(`magick identify $imageWithPathTypeDDS`,String)
            else
                identify = read(`identify $imageWithPathTypeDDS`,String)
            end
            a = split(split(identify," ")[3],"x")
            return true, parse(Int64,a[1]), parse(Int64,a[2])
        catch
            return false,0,0
        end
    else
        return false,0,0
    end
end


# Analyze the quality of the image
#  > 0  Image quality
# == 0  Image does not exist
#   -1  Image error
# Note: The algorithm does not work for DDS type files
function imageQuality(image, debugLevel)
    if isfile(image)
        try
            img = ImageView.load(image)
            sizeImg = size(img)[1]*size(img)[2]
            if debugLevel > 0 println("imageQuality - The file $image id downloaded the size is: $sizeImg") end
            return sizeImg
        catch err
            if debugLevel > 1 println("Error: imageQuality - The file $image is not downloaded") end
            return -2
        end
    else
        if debugLevel > 1 println("Error: imageQuality - The file $image is not present") end
        return -1
    end
end


function downloadImage(xy,lonLL,latLL,ΔLat,ΔLon,szWidth,szHight,sizeHight,imageWithPathTypePNG,task,debugLevel)
    # /World_Imagery/MapServer/export?bbox=16.0,38.0,16.125,38.0625&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
    x = xy[1]
    y = xy[2]
    imageMatrix = zeros(RGB{N0f8},szHight,szWidth)
    loLL = lonLL + (x - 1) * ΔLon
    loUR = lonLL + x * ΔLon
    laLL = latLL + (y - 1) * ΔLat
    laUR = latLL + y * ΔLat
    servicesWebUrlBase = "http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export?bbox="
    servicesWebUrl = servicesWebUrlBase * @sprintf("%03.6f,%03.6f,%03.6f,%03.6f",loLL,laLL,loUR,laUR) * "&bboxSR=4326&size=$szWidth,$szHight&imageSR=4326&format=png24&f=image"
    # HTTPD options from https://juliaweb.github.io/HTTP.jl/dev/public_interface/
    if debugLevel > 0 @warn "downloadImage - HTTP image start to download url: $servicesWebUrl" end
    tryDownloadFileImagePNG = 1
    downloadPNGIsComplete = 0
    t0 = time()
    while tryDownloadFileImagePNG <= 1 && downloadPNGIsComplete == 0
        io = IOBuffer(UInt8[], read=true, write=true)
        try
            r = HTTP.request("GET",servicesWebUrl,response_stream = io)
            if r == nothing || (r != nothing && r.status != 200)
                if debugLevel > 1 @warn "Error: downloadImage #1 - HTTP image download code: " * r.status * " residual try: $tryDownloadFileImagePNG" end
                tryDownloadFileImagePNG += 1
            else
                # In Julia there is a copy function between matrices which foresees to define the coordinates of the starting point.
                # This function is extremely efficient and fast, it allows to obtain a matrix of images.
                # Es: imageMatrix[1 + h * (y - 1):h * y,1 + w * (x - 1):w * x] = img
                try
                    ## imageMatrix[1 + sizeHight - (szHight * y):sizeHight - szHight * (y - 1),1 + szWidth * (x - 1):szWidth * x] = load(Stream(format"PNG", io))
                    imageMatrix = Images.load(Stream(format"PNG", io))
                    if debugLevel > 0 println(" ") end
                    # Print actual status
                    print("\rThe image in ",@sprintf("%03.3f,%03.3f,%03.3f,%03.3f",loLL,laLL,loUR,laUR)," load in the matrix: x = $x y = $y Task: $task th: $(Threads.threadid()) try: $tryDownloadFileImagePNG",@sprintf(" time: %3.2f",(time()-t0)))
                    downloadPNGIsComplete = 1
                catch err
                    if debugLevel > 1 @warn "Error: downloadImage #2 - load image $imageWithPathTypePNG is not downloaded, error id: $err" end
                end
            end
        catch err
            # Typical error type 500
            if debugLevel > 1 @warn "Error: downloadImage #3 - load image $imageWithPathTypePNG generic error id: $err" end
            tryDownloadFileImagePNG += 1
        end
        close(io)
    end
    return downloadPNGIsComplete,time()-t0,xy,imageMatrix
end


function downloadImages(lonLL,latLL,lonUR,latUR,cols,sizeWidth,imageWithPathTypePNG,debugLevel)
    sizeHight = Int(sizeWidth / (8 * tileWidth((latUR + latLL) / 2.0)))
    #imageMatrix = SharedArray(zeros(RGB{N0f8},sizeHight,sizeWidth))
    imageMatrix = SharedArray(zeros(RGB{N0f8},sizeHight,sizeWidth))
    downloadPNGIsCompleteNumber = 0
    szWidth = Int(sizeWidth / cols)
    szHight = Int(sizeHight / cols)
    ΔLat = (latUR - latLL) / cols
    ΔLon = (lonUR - lonLL) / cols
    indexValues = [(x,y) for x in 1:cols for y in 1:cols]
    fs = Dict{Int,Any}()
    @sync for task in 1:(cols*cols)
        @async fs[task] = downloadImage(indexValues[task],lonLL,latLL,ΔLat,ΔLon,szWidth,szHight,sizeHight,imageWithPathTypePNG,task,debugLevel)
    end
    res = Dict{Int,Tuple{Int64, Float64, Tuple{Int64, Int64}, Matrix{RGB{N0f8}}}}()
    @sync for task in 1:(cols*cols)
        @async res[task] = fetch(fs[task])
    end

    for task in 1:(cols*cols)
        x = res[task][3][1]
        y = res[task][3][2]
        imageMatrix[1 + sizeHight - (szHight * y):sizeHight - szHight * (y - 1),1 + szWidth * (x - 1):szWidth * x] = res[task][4]
        downloadPNGIsCompleteNumber += res[task][1]
    end

    if downloadPNGIsCompleteNumber > 0
        try
            Images.save(imageWithPathTypePNG,imageMatrix)
            if debugLevel > 0 println("downloadImage - The file $imageWithPathTypePNG is downloaded") end
        catch
            if debugLevel > 1 println("Error: downloadImage - to download the $imageWithPathTypePNG file, error id: ",err) end
            if isfile(imageWithPathTypePNG) rm(imageWithPathTypePNG) end
        end
    else
        if isfile(imageWithPathTypePNG) rm(imageWithPathTypePNG) end
    end

    return downloadPNGIsCompleteNumber
end


function createDDSFile(rootPath,tp,sizeWidth,cols,overWriteTheTiles,imageMagickPath,debugLevel)
    theBatchIsNotCompleted = false
    t0 = time()
    timeElaboration = nothing
    theDDSFileIsOk = 0
    tileIndex = 0
    fileSizePNG = 0
    fileSizeDDS = 0

    path = setPath(rootPath,tp[1],tp[2])
    if path != nothing
        tileIndex = tp[7]
        imageWithPathTypePNG = normpath(path * "/" * string(tp[7]) * ".png")
        imageWithPathTypeDDS = normpath(path * "/" * string(tp[7]) * ".dds")

        # Check the image DDS is present
        dataFileImageDDS = getDDSSize(imageWithPathTypeDDS)
        createDDSFile = false
        # Any images with PNG format are deleted
        if isfile(imageWithPathTypePNG) rm(imageWithPathTypePNG) end
        if dataFileImageDDS[1]
            if overWriteTheTiles >= 9
                rm(imageWithPathTypeDDS)
                theDDSFileIsOk = -1
            elseif overWriteTheTiles == 2 || dataFileImageDDS[2] < 512 || dataFileImageDDS[2] > 32768
                createDDSFile = true
            elseif overWriteTheTiles == 1 && sizeWidth > dataFileImageDDS[2]
                createDDSFile = true
            else
                theDDSFileIsOk = -3
            end
        else
            if isfile(imageWithPathTypeDDS) rm(imageWithPathTypeDDS) end
            if overWriteTheTiles < 9
                createDDSFile = true
            else
                theDDSFileIsOk = -2
            end
        end

        if createDDSFile
            #servicesWebUrl = "http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export?bbox="
            #servicesWebUrl = servicesWebUrl * @sprintf("%03.6f,%03.6f,%03.6f,%03.6f",tp[3],tp[5],tp[4],tp[6]) * "&bboxSR=4326&size=$sizeWidth,$sizeHight&imageSR=4326&format=png24&f=image"
            isfileImagePNG = downloadImages(tp[3],tp[5],tp[4],tp[6],cols,sizeWidth,imageWithPathTypePNG,debugLevel) > 0
            if isfileImagePNG > 0 && filesize(imageWithPathTypePNG) > 1024
                # Conversion from .png to .dds
                try
                    # Original version: -define dds:compression=DXT5 dxt5:$imageWithPathTypeDDS
                    # Compression factor (16K -> 64 MB): -define dds:mipmaps=0 -define dds:compression=dxt1
                    # Compression factor (16K -> 128 MB): -define dds:mipmaps=0 -define dds:compression=dxt5
                    oldFileIsPresent = isfile(imageWithPathTypeDDS)
                    fileSizePNG = stat(imageWithPathTypePNG).size
                    if Base.Sys.iswindows()
                        run(`magick convert $imageWithPathTypePNG -define dds:mipmaps=0 -define dds:compression=dxt1 $imageWithPathTypeDDS`)
                    else
                        imageMagickPath != nothing ? imageMagickWithPathUnix = normpath(imageMagickPath * "/" * "convert") : imageMagickWithPathUnix = "convert"
                        run(`$imageMagickWithPathUnix $imageWithPathTypePNG -define dds:mipmaps=0 -define dds:compression=dxt1 $imageWithPathTypeDDS`)
                    end
                    fileSizeDDS = stat(imageWithPathTypeDDS).size
                    if debugLevel > 0 println("createDDSFile - The file $imageWithPathTypeDDS is converted in the DDS file: $imageWithPathTypeDDS") end
                    rm(imageWithPathTypePNG)
                    theBatchIsNotCompleted = false
                    oldFileIsPresent ? theDDSFileIsOk = 2 : theDDSFileIsOk = 1
                    timeElaboration = time()-t0
                catch err
                    if debugLevel > 1 println("createDDSFile - Error to convert the $imageWithPathTypePNG file in dds format") end
                    try
                        rm(imageWithPathTypePNG)
                    catch
                        if debugLevel > 1 println("createDDSFile - Error to remove the $imageWithPathTypePNG file") end
                    end
                    theBatchIsNotCompleted = true
                    if theDDSFileIsOk == 0 theDDSFileIsOk = -10 end
                end
            else
                theBatchIsNotCompleted = true
                if theDDSFileIsOk == 0 theDDSFileIsOk = -11 end
            end
        else
            if theDDSFileIsOk == 0 theDDSFileIsOk = -12 end
        end
    end
    return theBatchIsNotCompleted, tileIndex, theDDSFileIsOk, timeElaboration, string(tp[7]) * ".dds","../" * tp[1] * "/" * tp[2], fileSizePNG, fileSizeDDS
end


# Main fuctions area

function parseCommandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--latll"
            help = "Lower left area lat"
            arg_type = Float64
            default = 0.0
        "--lonll"
            help = "Lower left area lon"
            arg_type = Float64
            default = 0.0
        "--latur"
            help = "Upper right area lat"
            arg_type = Float64
            default = 0.0
        "--lonur"
            help = "Upper right area lon"
            arg_type = Float64
            default = 0.0
        "--lat", "-a"
            help = "Latitude in deg of central point"
            arg_type = Float64
            default = 45.66
        "--lon", "-o"
            help = "Longitude in deg of central point"
            arg_type = Float64
            default = 9.7
        "--sexagesimal", "-x"
            help = "Set the sexagesimal unit degree.minutes"
            action = :store_true
        "--icao", "-i"
            help = "ICAO airport code for extract LAT and LON"
            arg_type = String
            default = nothing
        "--tile", "-t"
            help = "Tile index es coordinate reference"
            arg_type = Int64
            default = nothing
        "--radius", "-r"
            help = "Distance Radius around the center point (nm)"
            arg_type = Float64
            default = 0.0
        "--size", "-s"
            help = "Max size of image 0->512 1->1024 2->2048 3->4096 4->8192 5->16384 6->32768"
            arg_type = Int64
            default = 2
        "--over"
            help = "Overwrite the tiles: |1|only if bigger resolution |2|for all"
            arg_type = Int64
            default = 0
        "--path", "-p"
            help = "Path to store the dds images"
            arg_type = String
            default = "fgfs-scenery/photoscenery"
        "--attemps"
            help = "Number of download attempts"
            arg_type = Int64
            default = 3
        "--debug", "-d"
            help = "Debug level"
            arg_type = Int64
            default = 0
        "--version"
            help = "Program version"
            action = :store_true
    end

    return parse_args(s)
end


function cmgsExtract(cmgs,cols)
    a = []
    colsStop = Threads.nthreads() - cols
    if colsStop > Sys.CPU_THREADS colsStop = Sys.CPU_THREADS end
    if colsStop <= 0 colsStop = 1 end
    for cmg in cmgs
        if cmg[2] == 0
            push!(a,cmg[1])
            cmg[2] += 1
        end
        if size(a)[1] >= colsStop
            break
        end
    end
    return a
end


function cmgsExtractTest(cmgs)
    for cmg in cmgs
        if cmg[2] == 0
            return true
        end
    end
    return false
end


inValue(value,extrem) = abs(value) <= extrem


setDegreeUnit(isSexagesimal,degree) = isSexagesimal ? trunc(degree) + (degree - trunc(degree)) * (10.0/6.0) : degree


function main(args)

    centralPointLon = nothing
    centralPointLat = nothing

    imageMagickPath = inizialize()
    (imageMagickStatus, imageMagickPath) = checkImageMagick(imageMagickPath)
    if !imageMagickStatus
        println("\nThe program is then terminated as it is absolutely necessary to install ImageMagick (exit code 501)")
        ccall(:jl_exit, Cvoid, (Int32,), 501)
    end

    parsedArgs = parseCommandline()


    if parsedArgs["version"] return 0 end

    isSexagesimalUnit = parsedArgs["sexagesimal"]

    debugLevel = parsedArgs["debug"]
    if debugLevel > 1 @info "parsedArgs:" parsedArgs end

    # Process anothers options
    unCompletedTilesMaxAttemps = parsedArgs["attemps"]
    unCompletedTilesAttemps = 0
    centralPointRadiusDistance = parsedArgs["radius"]

    if parsedArgs["icao"] != nothing
        # Select lat lon by ICAO airport id or name or municipality
        # Test the DB csv or jdb
        if stat("airports.csv").mtime > stat("airports.jdb").mtime
            println("\nThe airports database 'airports.csv' is loading for conversion in airports.jdb file")
            JuliaDB.save(JuliaDB.loadtable("airports.csv"),"airports.jdb")
        elseif stat("airports.jdb").mtime == 0.0
            println("\nError: The airports.jdb file and airports.csv file is unreachable!\nPlease, make sure it is present in the photoscenary.jl program directory (exit code 403)")
            ccall(:jl_exit, Cvoid, (Int32,), 403)
        end
        try
            db = JuliaDB.load("airports.jdb")
            icaoIsFound = 400
            println("\nThe airports database 'airports.csv' is loading")
            searchString = Unicode.normalize(uppercase(parsedArgs["icao"]),stripmark=true)
            # Frist step try with ICAO ident
            foundDatas = filter(i -> (i.ident == searchString),db)
            if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] == 0
                foundDatas = filter(i -> occursin(searchString,Unicode.normalize(uppercase(i.municipality),stripmark=true)),db)
            end
            if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] == 0
                foundDatas = filter(i -> occursin(searchString,Unicode.normalize(uppercase(i.name),stripmark=true)),db)
            end
            if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] == 1
                icaoIsFound = 200
                if centralPointRadiusDistance == nothing || centralPointRadiusDistance <= 1.0 centralPointRadiusDistance = 10.0 end
                centralPointLat = foundDatas[1][:latitude_deg]
                centralPointLon = foundDatas[1][:longitude_deg]

                # Some airports have the location data multiplied by a thousand, in this case we proceed to the reduction
                if !(inValue(centralPointLat,90) && inValue(centralPointLon,180))
                    if abs(centralPointLat) > 1000.0 centralPointLat /= 1000.0 end
                    if abs(centralPointLon) > 1000.0 centralPointLon /= 1000.0 end
                end
                println("\nThe ICAO term $(parsedArgs["icao"]) is found in the database\n\tIdent: $(foundDatas[1][:ident])\n\tName: $(foundDatas[1][:name])\n\tCity: $(foundDatas[1][:municipality])\n\tCentral point lat: $(round(centralPointLat,digits=4)) lon: $(round(centralPointLon,digits=4)) radius: $centralPointRadiusDistance nm")
            else
                if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] > 1
                    icaoIsFound = 401
                    println("\nError: The ICAO search term $(parsedArgs["icao"]) is ambiguous, there are $(JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1]) airports with a similar term (exit code 402)")
                    cycle = 0
                    for data in foundDatas
                        println("\tId: $(data[:ident])\tname: $(data[:name]) ($(data[:municipality]))")
                        cycle += 1
                        if cycle > 30 break end
                    end
                    println("\n(exit code 402)")
                    ccall(:jl_exit, Cvoid, (Int32,), 402)
                else
                    icaoIsFound = 400
                    println("\nError: The ICAO search term $(parsedArgs["icao"]) is not found in the airports.csv database (exit code 400)")
                    ccall(:jl_exit, Cvoid, (Int32,), 400)
                end
            end
        catch err
            println("\nError: The airports.jdb file is corrupt\n\tPlease, make sure if airports.csv file is present in the program directory\n\tRemove the corrupt airports.jdb file and restart the program\nError code is $err (exit code 404)")
            ccall(:jl_exit, Cvoid, (Int32,), 404)
        end
    elseif parsedArgs["tile"] != nothing
        if parsedArgs["tile"] > 20
            centralPointLon = coordFromIndex(parsedArgs["tile"])[1]
            centralPointLat = coordFromIndex(parsedArgs["tile"])[2]
        else
            println("\nError: the value of the tile id $(parsedArgs["tile"]) is too small,\n\tit could be a value related to the thread number of the julia compiler\n\tcheck the command line. (exit code 403)")
            ccall(:jl_exit, Cvoid, (Int32,), 403)
        end
    else
        centralPointLat = setDegreeUnit(isSexagesimalUnit,parsedArgs["lat"])
        centralPointLon = setDegreeUnit(isSexagesimalUnit,parsedArgs["lon"])
        if centralPointRadiusDistance == 0.0 centralPointRadiusDistance = 10.0 end
    end

    if centralPointLat == nothing || centralPointLon == nothing
        println("\nError: processing will stop! The LAT or LON is invalid (exit code 405)")
        ccall(:jl_exit, Cvoid, (Int32,), 405)
    end

    overWriteTheTiles = parsedArgs["over"]
    size = parsedArgs["size"]

    # Only for testing! Remove when cols function is implemented

    if size <= 0
        sizeWidth = 512
        cols = 1
    elseif size == 1
        sizeWidth = 1024
        cols = 1
    elseif size == 2
        sizeWidth = 2048
        cols = 1
    elseif size == 3
        sizeWidth = 4096
        cols = 2
    elseif size == 4
        sizeWidth = 8192
        cols = 4
    elseif size == 5
        sizeWidth = 16384
        cols = 8
    elseif size >= 6
        sizeWidth = 32768
        cols = 8
    end

    unCompletedTilesMaxAttempsBaseSize = Int64(sizeWidth / 2)
    if unCompletedTilesMaxAttempsBaseSize > 1024 unCompletedTilesMaxAttempsBaseSize = 1024 end

    # Check if the coordinates are consistent
    systemCoordinatesIsPolar = nothing
    if (parsedArgs["latll"] < parsedArgs["latur"]) && (parsedArgs["lonll"] < parsedArgs["lonur"])
        latLL = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["latll"]),digits=3)
        lonLL = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["lonll"]),digits=3)
        latUR = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["latur"]),digits=3)
        lonUR = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["lonur"]),digits=3)
        systemCoordinatesIsPolar = false
    end
    if centralPointLat != nothing && centralPointLon != nothing && centralPointRadiusDistance > 0.0 && systemCoordinatesIsPolar == nothing
        (latLL,lonLL,latUR,lonUR) = latDegByCentralPoint(centralPointLat,centralPointLon,centralPointRadiusDistance)
        systemCoordinatesIsPolar = true
    end
    if systemCoordinatesIsPolar == nothing
        println("\nError: The process will terminate as the entered coordinates are not consistent")
        ccall(:jl_exit, Cvoid, (Int32,), 505)
    end

    # Check the coordinates
    if !(inValue(latLL,90) && inValue(lonLL,180) && inValue(latUR,90) && inValue(lonUR,180))
        println("\nError: The process will terminate as the entered coordinates are not consistent\n\tlatLL: $latLL lonLL: $lonLL latUR: $latUR lonUR: $lonUR")
        ccall(:jl_exit, Cvoid, (Int32,), 505)
    end

    # Path prepare
    pathToTest = normpath(parsedArgs["path"])
    if Base.Sys.iswindows()
        if pathToTest[2] == ':' || pathToTest[1] == '\\'
            rootPath = normpath(parsedArgs["path"] * "/Orthophotos")
        else
            cd();
            rootPath = normpath(pwd() * "/" * parsedArgs["path"] * "/Orthophotos")
        end
    else
        if pathToTest[1] == '/'
            rootPath = normpath(parsedArgs["path"] * "/Orthophotos")
        else
            cd();
            rootPath = normpath(pwd() * "/" * parsedArgs["path"] * "/Orthophotos")
        end
    end

    # Download thread
    continueToReatray = true
    unCompletedTilesNumber = 0
    numbersOfTilesToElaborate = 0
    numbersOfTilesInserted = 0
    numbersOfTilesElaborate = 0
    timeElaborationForAllTilesInserted = 0.0
    timeElaborationForAllTilesResidual = 0.0
    timeStart = time()
    ifFristCycle = true
    totalByteDDS = 0
    totalBytePNG = 0

    while continueToReatray
        # Generate the coordinate matrix

        # Resize management with smaller dimensions
        if ifFristCycle
            sizeWidthByAttemps = sizeWidth
        else
            if unCompletedTilesAttemps > 0
                sizeWidthByAttemps = Int64(unCompletedTilesMaxAttempsBaseSize / 2^(unCompletedTilesAttemps - 1))
            else
                sizeWidthByAttemps = sizeWidth
            end
        end

        if ifFristCycle
            (cmgs,cmgsSize) = coordinateMatrixGenerator(latLL,lonLL,latUR,lonUR,systemCoordinatesIsPolar,nothing,debugLevel)
            numbersOfTilesToElaborate = cmgsSize
        else
            (cmgs,cmgsSize) = coordinateMatrixGenerator(latLL,lonLL,latUR,lonUR,systemCoordinatesIsPolar,unCompletedTiles,debugLevel)
            numbersOfTilesToElaborate = cmgsSize
        end
        println("\nStart the elaboration n. $(unCompletedTilesAttemps+1) for $numbersOfTilesToElaborate tiles the Area deg is",
            @sprintf(" latLL: %02.3f",latLL),
            @sprintf(" lonLL: %03.3f",lonLL),
            @sprintf(" latUR: %02.3f",latUR),
            @sprintf(" lonUR: %03.3f",lonUR),
            " Batch size: $cmgsSize",
            " Width pix: $sizeWidthByAttemps",
            " Cycle: $unCompletedTilesAttemps",
            "\nThe images path is: $rootPath\n")

        while cmgsExtractTest(cmgs)
            threadsActive = 0
            Threads.@threads for cmg in cmgsExtract(cmgs,cols)
                threadsActive += 1
                theBatchIsNotCompleted = false
                (theBatchIsNotCompleted,tileIndex,theDDSFileIsOk,timeElaboration,tile,pathRel,fileSizePNG,fileSizeDDS) = createDDSFile(rootPath,cmg,sizeWidthByAttemps,cols,overWriteTheTiles,imageMagickPath,debugLevel)
                if theDDSFileIsOk >= 1
                    numbersOfTilesElaborate += 1
                    if timeElaboration != nothing && theBatchIsNotCompleted == false
                        timeElaborationForAllTilesInserted += timeElaboration
                        numbersOfTilesInserted += 1
                    end
                    if haskey(unCompletedTiles,tileIndex)
                        delete!(unCompletedTiles,tileIndex)
                        unCompletedTilesNumber -= 1
                    end
                elseif theBatchIsNotCompleted
                    if haskey(unCompletedTiles,tileIndex)
                        push!(unCompletedTiles,tileIndex => unCompletedTiles[tileIndex] + 1)
                    else
                        push!(unCompletedTiles,tileIndex => 1)
                    end
                    if ifFristCycle unCompletedTilesNumber += 1 end
                else
                    numbersOfTilesElaborate += 1
                end
                if theDDSFileIsOk != 0
                    if theDDSFileIsOk == 1
                        theDDSFileIsOkStatus = "(Inserted)"
                        totalBytePNG += fileSizePNG
                        totalByteDDS += fileSizeDDS
                    elseif theDDSFileIsOk == 2
                        totalBytePNG += fileSizePNG
                        totalByteDDS += fileSizeDDS
                        theDDSFileIsOkStatus = "(Updated)   "
                    elseif theDDSFileIsOk == -1
                        theDDSFileIsOkStatus = "(Removed)   "
                    elseif theDDSFileIsOk == -2
                        theDDSFileIsOkStatus = "(Nothing)   "
                    elseif theDDSFileIsOk == -3
                        theDDSFileIsOkStatus = "(Skip)      "
                    elseif theDDSFileIsOk <= -10
                        theDDSFileIsOkStatus = "(HTTP! $theDDSFileIsOk) "
                    end
                    timeElaborationForAllTilesResidual = (timeElaborationForAllTilesInserted / numbersOfTilesInserted) * numbersOfTilesToElaborate / Threads.nthreads()
                    println('\r',
                        @sprintf("Time: %6d",time()-timeStart),
                        @sprintf(" elab: %6d",timeElaborationForAllTilesInserted),
                        @sprintf(" (%5.1f|",(time()-timeStart) / numbersOfTilesInserted),
                        @sprintf("%5.0f)",timeElaborationForAllTilesResidual),
                        @sprintf(" Tiles: %4d",numbersOfTilesElaborate),
                        @sprintf(" on %4d",numbersOfTilesToElaborate),
                        @sprintf(" res %4d",(numbersOfTilesToElaborate - numbersOfTilesElaborate)),
                        @sprintf(" err %4d",unCompletedTilesNumber),
                        @sprintf(" Th: %2d",threadsActive),
                        " path: $pathRel/$tile ",
                        @sprintf(" MB/s: %3.2f",totalBytePNG / (time()-timeStart) / 1000000),
                        @sprintf(" MB dw: %6.1f ",totalByteDDS / 1000000),
                        theDDSFileIsOkStatus
                    )
                else
                    totalBytePNG += fileSizePNG
                end
            end
        end
        # Check the incomplete Tiles
        continueToReatray = false
        isIncompleteTileList = false
        for idTile in collect(keys(unCompletedTiles))
            if !isIncompleteTileList
                println("\nIncomplete tiles list:")
                unCompletedTilesAttemps += 1
            end
            isIncompleteTileList = true
            println("Tile id: ",idTile," attemps: ",unCompletedTilesAttemps)
            if unCompletedTilesAttemps <= unCompletedTilesMaxAttemps
                continueToReatray = true
                numbersOfTilesElaborate = 0
            else
                continueToReatray = false
            end
        end
        if !ifFristCycle && !continueToReatray println("\nThe maximum number of attempts has been reached, some tiles have not been inserted as they cannot be reached") end
        ifFristCycle = false
    end
    println("\n\nThe process is finish, ",@sprintf("Time elab: %5.1f ",time()-timeStart)," number of tiles: ",numbersOfTilesToElaborate," time for tile: ",@sprintf("%5.1f",(time()-timeStart)/numbersOfTilesToElaborate),@sprintf(" MB/s: %3.2f",totalBytePNG / (time()-timeStart) / 1000000),@sprintf(" MB dw: %6.1f ",totalByteDDS / 1000000))

end

main(ARGS)
