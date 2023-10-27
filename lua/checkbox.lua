-- MIT License
-- 
-- Copyright (c) 2023 Stefan Rakel
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- Initialize patterns
local prefixPatterns = {"%-", "%*", "#+", "%->", "=>", "%d+%."}
local skipPatterns = {"%-", "%*", "%->", "=>", "%d+%."}

if vim.g.checkbox_prefixPatterns then
	prefixPatterns = vim.g.checkbox_prefixPatterns
end
if vim.g.checkbox_skipPatterns then
	prefixPatterns = vim.g.checkbox_skipPatterns
end

-- returns indentation level, checked status and text if the line has a checbox
-- nil otherwise
local function getCheckboxFromLine(lineNum)
	local line = vim.fn.getline(lineNum)
	for _, pat in ipairs(prefixPatterns) do
		local pattern = "(%s*)(" .. pat .. "%s*)%[([ xX]?)%](.*)"
		local whitespace, before, checked, after = string.match(line, pattern)
		if whitespace then
			if checked == "x" or checked == "X" then
				checked = true
			else
				checked = false
			end
			whitespace = string.gsub(whitespace, "\t", " ")
			local indentation = string.len(whitespace)
			return {lineNum=lineNum, indentation=indentation, checked=checked, before=before, after=after}
		end
	end
	return nil
end

local function writeCheckbox(checkbox)
	local checkedString = " "
	if checkbox.checked then
		checkedString = "X"
	end
	local newLine = string.rep(" ", checkbox.indentation) .. checkbox.before .. "[" .. checkedString .. "]" .. checkbox.after
	vim.fn.setline(checkbox.lineNum, newLine)
end

local function setCheckbox(checkbox, checked)
	checkbox.checked = checked
	writeCheckbox(checkbox)
end

local function switchOrAddCheckbox(lineNum)
	local checkbox = getCheckboxFromLine(lineNum)
	if checkbox then
		checkbox.checked = not checkbox.checked
		writeCheckbox(checkbox)
		return checkbox
	else
		for _, pat in ipairs(prefixPatterns) do
			local pattern = "(%s*" .. pat .. "%s*)(.*)"
			local before, after = string.match(vim.fn.getline(lineNum), pattern)
			if before then
				local newLine = before .. "[ ] " .. after
				vim.fn.setline(lineNum, newLine)
				return getCheckboxFromLine(lineNum)
			end
		end
		return nil
	end
end

local function findParent(startCheckbox)
		if not startCheckbox then
			return false
		end
		local lineNum = startCheckbox.lineNum
		while true do
			lineNum = lineNum - 1
			local checkbox = getCheckboxFromLine(lineNum)
			if not checkbox then
				--check skip patterns
				local skipped = false
				for _, pat in ipairs(skipPatterns) do
					if string.match(vim.fn.getline(lineNum), "%s*" .. pat .. ".*") then
						skipped = true
					end
				end
				if not skipped then
					return false
				end
			else
				if checkbox.indentation < startCheckbox.indentation then
					return checkbox
				end
			end
		end
end

local function findChildren(startCheckbox)
	if not startCheckbox then
		return false
	end
	local children = {}
	local lineNum = startCheckbox.lineNum
	while true do
		lineNum = lineNum + 1
		local checkbox = getCheckboxFromLine(lineNum)
		if not checkbox then
			--check skip patterns
			local skipped = false
			for _, pat in ipairs(skipPatterns) do
				if string.match(vim.fn.getline(lineNum), "%s*" .. pat .. ".*") then
					skipped = true
				end
			end
			if not skipped then
				return children
			end
		elseif checkbox.indentation == startCheckbox.indentation then
			return children
		elseif checkbox.indentation > startCheckbox.indentation then
			table.insert(children, checkbox)
		end
	end
	return children
end

local function updateFromChildren(checkbox)
	local children = findChildren(checkbox)
	if not children then
		return
	end
	local total = 0
	local checked = 0
	for _, child in ipairs(children) do
		if not child.checked then
			setCheckbox(checkbox, false)
			return
		end
	end
	setCheckbox(checkbox, true)
end

local function updateChildren(checkbox)
	local children = findChildren(checkbox)
	if not children then
		return
	end
	for _, child in ipairs(children) do
		setCheckbox(child, checkbox.checked)
	end
end

local function switchAndUpdateCheckbox()
	local lineNum = vim.fn.line(".")
	checkbox = switchOrAddCheckbox(lineNum)
	if checkbox then
		-- Update children
		updateChildren(checkbox)
		-- Traverse parents upwards and update them
		local parent = findParent(checkbox)
		while parent do
			updateFromChildren(parent)
			parent = findParent(parent)
		end
	end
end

return {
	checkbox = switchAndUpdateCheckbox
}
	
