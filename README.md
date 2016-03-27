# **Artal**
### A .PSD parsing library for LÖVE

Purpose is to expose the structure of .PSD files into LÖVE.
- ImageData for the layers.
- Names.
- Blendmodes.
- Clipping mode.
- Structure, folder / image.

![](https://u.pomf.is/sbzsva.gif)

## artal.lua
```lua
artal = require("artal")
psdTable = artal.newPSD(FileNameOrFileData) --full structure with the layers loaded in as images.
psdTable = artal.newPSD(FileNameOrFileData, "info") --full structure.
ImageDataOrNil = artal.newPSD(FileNameOrFileData, layerNumber) --ImageData for the specified layer number.
ImageData = artal.newPSD(FileNameOrFileData, "composed")
-- ImageData of the composed image as it's stored in the psd file itself.
-- Note that Photoshop has an slightly erroneous implementation composing the alpha into the composed image.
-- So images without a fully opaque background will be slightly blended with white.
```

### Full structure
```
width: width of the composed image.
height: height of the composed image.
Numbered Indexes: All the layers as tables.
	name: name of layer / folder
	type: type of the layer
	blend: blendmode of layer / folder. See below for available modes
	clip: Boolean if the layer is a clipping layer.
	if type "image" then -- image layer with an image
		image: image for the layer.
		ox: offset for the layer. Pass in these to the ox and oy parameters of love.graphics.draw().
		oy: 
	if type "empty" then -- image layer without an image
		nothing extra.
	if type "open" then -- folder open layer
		nothing extra.
	if type "close" then -- folder close layer
		nothing extra.
```
### BlendModes
These are all blendmodes available.
```
There's sample code for these first 5 blendmodes.
"norm" = normal
"pass" = pass through
"mul"  = multiply
"scrn" = screen
"over" = overlay

"diss" = dissolve
"dark" = darken
"idiv" = color burn
"lbrn" = linear burn
"dkCl" = darker color
"lite" = lighten
"div"  = color dodge
"lddg" = linear dodge
"lgCl" = lighter color
"sLit" = soft light
"hLit" = hard light
"vLit" = vivid light
"lLit" = linear light
"pLit" = pin light
"hMix" = hard mix
"diff" = difference
"smud" = exclusion
"fsub" = subtract
"fdiv" = divide
"hue"  = hue
"sat"  = saturation
"colr" = color
"lum"  = luminosity
```
```
Adobe documentation on the PSD file format.
http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
```

### Sample code:
![](https://u.pomf.is/klltkn.png)
```lua
local artal = require("artal")
love.graphics.setBackgroundColor(255,255,255)

img = artal.newPSD("sample.psd")

function love.draw()
	for i = 1, #img do
        love.graphics.draw(
            img[i].image,
            nil, -- Position X
            nil, -- Position Y
            nil, -- Rotation
            nil, -- Scale X
            nil, -- Scale Y
            img[i].ox, -- Offset X
            img[i].oy) -- Offset Y
    end
end
```

### Show information artal extracts from the psd file
![](https://u.pomf.is/vrwgck.png)
```lua
local artal = require("artal")
love.graphics.setBackgroundColor(255,255,255)

img = artal.newPSD("sample.psd")

function love.draw()

	-- Image info.
	love.graphics.setColor(0,0,0)
	love.graphics.print("Global Image info", 0, 14*0)
	love.graphics.print("Layer Count: "..#img, 0, 14*1)
	love.graphics.print("Width: "..img.width, 0, 14*2)
	love.graphics.print("Height: "..img.height, 0, 14*3)
	for i = 1, #img do
		love.graphics.setColor(0,0,0)
		love.graphics.print("Layer index: "..i, (i-1)*200, 70+14*0)
		love.graphics.print("name: "..img[i].name, (i-1)*200, 70+14*1)
		love.graphics.print("type: "..img[i].type, (i-1)*200, 70+14*2)
		love.graphics.print("blend: "..img[i].blend, (i-1)*200, 70+14*3)
		love.graphics.print("clip: "..tostring(img[i].clip), (i-1)*200, 70+14*4)
		love.graphics.print("ox: "..img[i].ox, (i-1)*200, 70+14*5)
		love.graphics.print("oy: "..img[i].oy, (i-1)*200, 70+14*6)
		love.graphics.print("getWidth: "..img[i].image:getWidth(), (i-1)*200, 70+14*7)
		love.graphics.print("getHeight: "..img[i].image:getHeight(), (i-1)*200, 70+14*8)
		
		-- Bounding Boxes
		love.graphics.rectangle(
			"line",
			(i-1)*200-img[i].ox-0.5,
			70+14*9-img[i].oy-0.5,
			img[i].image:getWidth()+1,
			img[i].image:getHeight()+1)

		love.graphics.setColor(255,255,255)
		love.graphics.draw(
			img[i].image,
			(i-1)*200,
			70+14*9,
			nil,
			nil,
			nil,
			img[i].ox,
			img[i].oy)
	end
	
end
```
### Clipping sample
![](https://u.pomf.is/ubvsna.png)
```lua
local artal = require("artal")
local psdShader = require("psdShader")
love.graphics.setBackgroundColor(255,255,255)

img = artal.newPSD("sample.psd")

local blendShader = {}
blendShader.clip = love.graphics.newShader(psdShader.createShaderString("norm", "norm", "over"))

function love.draw()
	love.graphics.draw(img[1].image,nil,nil,nil,nil,nil,img[1].ox,img[1].oy)
	psdShader.setShader(blendShader.clip)
	psdShader.drawClip(1,img[3].image,nil,nil,nil,nil,nil,img[3].ox,img[3].oy)
	psdShader.drawClip(2,img[4].image,nil,nil,nil,nil,nil,img[4].ox,img[4].oy)
	love.graphics.draw(img[2].image,nil,nil,nil,nil,nil,img[2].ox,img[2].oy)
	love.graphics.setShader()
end
```

### Blendmode sample
![](https://u.pomf.is/ntxeen.png)
```lua
local artal = require("artal")
local psdShader = require("psdShader")
love.graphics.setBackgroundColor(255,255,255)

img = artal.newPSD("sample.psd")

local blendShader = {}
blendShader.mul = love.graphics.newShader(psdShader.createShaderString("mul"))
blendShader.scrn = love.graphics.newShader(psdShader.createShaderString("scrn"))
blendShader.over = love.graphics.newShader(psdShader.createShaderString("over"))

local canvas = {}
canvas[1] = love.graphics.newCanvas(love.graphics.getDimensions())
canvas[2] = love.graphics.newCanvas(love.graphics.getDimensions())

function love.draw()

	love.graphics.setCanvas(canvas[1])
	love.graphics.clear(255,255,255)

	for i = 1, #img do
		if img[i].blend == "mul" or
			img[i].blend == "over" or
			img[i].blend == "scrn" then
			
			psdShader.setShader(blendShader[img[i].blend],canvas[1],canvas[2])
		end
		love.graphics.draw(img[i].image,nil,nil,nil,nil,nil,img[i].ox,img[i].oy)
		love.graphics.setShader()
	end
	
	-- Draw result to screen
	local preCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(nil)
	love.graphics.setBlendMode("alpha","premultiplied")
	love.graphics.draw(preCanvas)
	love.graphics.setBlendMode("alpha")
end
```
### Blend and Clipping
![](https://u.pomf.is/zjpidx.png)
```lua
local artal = require("artal")
local psdShader = require("psdShader")
love.graphics.setBackgroundColor(255,255,255)

img = artal.newPSD("sample.psd")

local blendShader = {}
blendShader.clipAndBlend = love.graphics.newShader(psdShader.createShaderString("mul", "over", "scrn"))

local canvas = {}
canvas[1] = love.graphics.newCanvas(love.graphics.getDimensions())
canvas[2] = love.graphics.newCanvas(love.graphics.getDimensions())

function love.draw()
	love.graphics.setCanvas(canvas[1])
	love.graphics.clear(255,255,255)

	love.graphics.draw(img[1].image,nil,nil,nil,nil,nil,img[1].ox,img[1].oy)
    psdShader.setShader(blendShader.clipAndBlend, canvas[1], canvas[2])
    psdShader.drawClip(1,img[3].image,nil,nil,nil,nil,nil,img[3].ox,img[3].oy)
    psdShader.drawClip(2,img[4].image,nil,nil,nil,nil,nil,img[4].ox,img[4].oy)
    love.graphics.draw(img[2].image,nil,nil,nil,nil,nil,img[2].ox,img[2].oy)
    love.graphics.setShader()
	
	-- Draw result to screen
	local preCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(nil)
	love.graphics.setBlendMode("alpha","premultiplied")
	love.graphics.draw(preCanvas)
	love.graphics.setBlendMode("alpha")
end
```

### Loading specific layers.
![](https://u.pomf.is/exmlfg.png)
```lua
local artal = require("artal")
love.graphics.setBackgroundColor(255,255,255)

img = artal.newPSD("sample.psd","info")

for i = 1, #img do
	if img[i].type == "image" and string.find(img[i].name, "Blob") then -- Only load layers with Blob in the name
		img[i].image = love.graphics.newImage(artal.newPSD("sample.psd", i))
	end
end

function love.draw()
	for i = 1, #img do
		if img[i].image then
	        love.graphics.draw(
	            img[i].image,
	            nil,
	            nil,
	            nil,
	            nil,
	            nil,
	            img[i].ox,
	            img[i].oy)
	    end
    end
end
```

### Structure of the table returned from artal.newPSD()
This structure is generated from writetable.lua. And you can use that to visualize your own tables.

```lua
{
	-- Table with 4 indexes, and 2 string keys.
	-- Array values are all of type: "table".
	height = 200,
	width = 200,
	[1] = 
	{
		-- Table with 7 string keys.
		oy = 0,
		image = "Image: 0x6b119bff80",
		ox = 0,
		type = "image",
		blend = "norm",
		name = "Background",
		clip = false,
	},
	[2] = 
	{
		-- Table with 7 string keys.
		oy = -40,
		image = "Image: 0x6b119c0140",
		ox = -68,
		type = "image",
		blend = "norm",
		name = "Red Blob",
		clip = false,
	},
	[3] = 
	{
		-- Table with 7 string keys.
		oy = -17,
		image = "Image: 0x6b119c0220",
		ox = -95,
		type = "image",
		blend = "norm",
		name = "Blue Blob",
		clip = true,
	},
	[4] = 
	{
		-- Table with 7 string keys.
		oy = -27,
		image = "Image: 0x6b12844c80",
		ox = -8,
		type = "image",
		blend = "over",
		name = "Multiple Blobs",
		clip = true,
	},
}
```

### psdShader.lua:
Small library to generate shaders for blending and clipping layers.
Blendmodes implemented: Alpha, Multiply, Screen and Overlay.
```lua
local psdShader = require("psdShader")
shaderString = psdShader.createShaderString(globalBlendmode, blendmodeBeingClipped, ...)
psdShader.setShader(shader)
psdShader.drawClip(drawOrderIndex,image,x,y,r,sx,sy,ox,oy,kx,ky) -- (Rotation and shearing not implemented.)
resultCanvas = psdShader.flatten(psdTableClipTo, psdTableBeingClipped, ...)
```

### writetable.lua
Create a string from tables. So you can inspect tables created by artal.newPSD(). Or anything else for that matter.
```lua
local writetable = require("writetable")
tableAsString = writetable.createStringFromTable(table)
```
