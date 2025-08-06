
entriesToRender = 20

// Entry class

Entry = {}
Entry.init = function(idx, name, isDir)
	self.idx = idx
	self.name = name
	self.isDir = isDir
end function
Entry.isMiniScript = function()
	return endsWith(self.name, ".ms")
end function

newFileEntry = function(idx, name)
	e = new Entry
	e.init(idx, name, false)
	return e
end function

newDirEntry = function(idx, name)
	e = new Entry
	e.init(idx, name, true)
	return e
end function

// File navigator
Nav = {}

Nav.path = ""
Nav.entries = []
Nav.entryIdx = 0
Nav.topIdx = 0
Nav.bottomIdx = 0
Nav.maxIdx = function()
	return self.entries.len - 1
end function

Nav.computeEntries = function()
	self.entryIdx = 0
	self.topIdx = 0
	self.entries = []
	self.path = file.curdir
	
	dirEntries = []
	fileEntries = []
	
	parentDir = newDirEntry(0, "..")
	dirEntries.push parentDir
	
	idx = 0
	for entryName in file.children
		if not self.ignoreFile(entryName) then
			if isDir(entryName) then
				e = newDirEntry(idx, entryName)
				dirEntries.push e
				idx = idx + 1
			end if
		end if
	end for	
	
	for entryName in file.children
		if not self.ignoreFile(entryName) then
			if not isDir(entryName) then
				e = newFileEntry(idx, entryName)
				fileEntries.push e
				idx = idx + 1
			end if
		end if
	end for	
	
	// Sort alphabetically
	dirEntries.sort("name")
	fileEntries.sort("name")
	
	// Combine and add - dirs first
	for e in dirEntries
		self.entries.push e
	end for
	
	for e in fileEntries
		self.entries.push e
	end for
	
	// Reserve 2 entries for scroll up / down indicators
	self.bottomIdx = self.topIdx + entriesToRender - 2
	
end function

Nav.computeRootEntries = function()
	self.entryIdx = 0
	self.topIdx = 0
	self.entries = []
	self.path = "MOUNTPOINTS"
	
	self.entries.push(newDirEntry(0, "/sys"))
	
	idx = 1
	if file.exists("/usr") then 
		self.entries.push(newDirEntry(idx, "/usr"))
		idx = idx + 1
	end if
	if file.exists("/usr2") then 
		self.entries.push(newDirEntry(idx, "/usr2"))
	end if
	
	self.bottomIdx = self.entries.len - 1
end function

Nav.ignoreFile = function(entryName)
	if startsWith(entryName, ".") then return true
	return false
end function

Nav.printScreen = function()
	clear
	text.delimiter = char(13)
	text.row = 25
	text.column = 0
	
	text.color = color.orange
	print self.path
	print ""
	
	self.printEntries
	print ""
end function

Nav.printEntries = function()
	renderIdx = self.topIdx
	
	if self.topIdx > 0 then
		text.color = color.white
		print "(...)"	
	end if
	
	for entry in self.entries[self.topIdx:self.bottomIdx+1]
		if renderIdx > self.bottomIdx then
			break
		end if
		if entry.isDir then
			text.color = color.aqua
		else
			text.color = color.silver
		end if
		
		if renderIdx == self.entryIdx then
			text.inverse = true
			print entry.name
			text.inverse = false
		else
			print entry.name
		end if
		
		renderIdx = renderIdx + 1
	end for
	
	if self.maxIdx > self.bottomIdx then
		text.delimiter = ""
		text.color = color.white
		print "(...)"
		text.delimiter = char(13)
		text.color = color.silver
	end if
	
end function

Nav.moveUp = function()
	if self.entryIdx > 0 then 
		self.entryIdx = self.entryIdx - 1
		// Need to scroll up?
		if self.entryIdx < self.topIdx then
			self.topIdx = self.topIdx - 1
			self.bottomIdx = self.bottomIdx - 1
		end if
		Nav.printScreen
	end if
end function

Nav.moveDown = function()
	if self.entryIdx < self.maxIdx then 
		self.entryIdx = self.entryIdx + 1
		// Need to scroll down?
		if self.entryIdx > self.bottomIdx then
			self.topIdx = self.topIdx + 1
			self.bottomIdx = self.bottomIdx + 1
		end if
		Nav.printScreen
	end if	
end function

Nav.currentEntry = function()
	entry = self.entries[self.entryIdx]
	return entry
end function

Nav.enter = function()
	// If directory, navigate to it
	currEntry = self.currentEntry
	if currEntry.isDir then
		self.enterDir
	else if currEntry.isMiniScript then
		load currEntry.name
		exit
	else
		self.view
	end if
end function

Nav.view = function()
	currEntry = self.currentEntry
	if currEntry.isDir then 
		return		
	else if self.isTextFile(currEntry.name) then
		self.viewTextFile currEntry.name
		self.printScreen		
	else
		view currEntry.name
		
		self.printScreen
	end if
end function

Nav.isTextFile = function(path)
	return (path[-4:] == ".txt" or 
	path[-3:] == ".ms" or 
	path[-4:] == ".tsv" or 
	path[-5:] == ".json" or 
	path[-3:] == ".md")
end function

Nav.viewTextFile = function(path)	
	lines = file.readLines(path)
	// Wrap each line to 68 columns.
	i = 0
	while i < lines.len
		lines[i] = lines[i].replace(char(9), "    ")
		if lines[i].len > 68 then
			lines.insert i+1, lines[i][68:]
			lines[i] = lines[i][:68]
		end if
		i = i + 1
	end while
	// Force showing "more" by adding lines
	if lines.len < 24 then
		for i in range(1,50-lines.len)
			lines.push " "
		end for
	end if
	// TODO: come up with own, better, implementation
	// using scrolling ...
	pageThrough lines
	// Pause
	pause
end function

pause = function()
	text.inverse = true
	text.row = 0
	text.delimiter = ""
	print "Press any key ..."
	text.inverse = false
	while true
		if key.available then break
	end while
	text.delimiter = char(13)
end function

Nav.enterDir = function()
	currEntry = self.currentEntry
	if currEntry.name == ".." then
		self.enterParentDir
	else
		file.setdir(currEntry.name)
		self.computeEntries
	end if
	self.printScreen	
end function

Nav.enterParentDir = function()
	if self.path == "/usr" or self.path == "/sys" or self.path == "/usr2" then
		// Simulate a "root" directory where you can choose the main
		// root dirs like "/usr", "/sys" and "/usr2".
		self.computeRootEntries
	else
		// Just do a normal change of directory
		file.setdir(self.currentEntry.name)
		self.computeEntries		
	end if
end function

isDir = function(entryName)
	i = file.info(entryName)
	return i.isDirectory
end function

startsWith = function(str, s)
	return str.len >= s.len and str[:s.len] == s
end function

endsWith = function(str, s)
	return str.len >= s.len and str[-s.len:] == s
end function

Nav.run = function()
	self.computeEntries
	self.printScreen
	
	while true
		if key.available then
			k = key.get
			if key.pressed("up") then Nav.moveUp
			if key.pressed("down") then Nav.moveDown
			if key.pressed("return") then Nav.enter
			if k == "v" then Nav.view
			if k == "q" or key.pressed("escape") then break
		end if
		yield
	end while
end function

if globals == locals then Nav.run
