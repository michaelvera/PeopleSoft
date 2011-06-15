#!/usr/bin/ruby

##############################################################################
# HealthStatCompareWithWalgreens.rb
#
# 11May2011 - Michael Vera
#
# Opens a spreadsheet from Walgreens to compare their HealthStat compliance
#  details with PeopleSoft's.
#
# The spreadsheet has EMPLID in column C as '000011221' 
#  and status as Y or N in column O
##############################################################################

require 'date'
require 'oci8'
require 'rubygems'
require 'spreadsheet'

# Set the object 'today' to the date using the Date class
today = Date.today

mysql = ''

# Open existing worksheet
walgreensBook = Spreadsheet.open 'FullWalgreens.xls'
walgreensSheet = walgreensBook.worksheet 0


# Create database connection with the OCI8 Oracle driver
db = OCI8.new('psadm','Orac1e11','hrpd')


# Create new spreadsheet instance with each systems status and the emplid
outputBook = Spreadsheet::Workbook.new
outputSheet = outputBook.create_worksheet 
outputSheet.name = 'PeopleSoft vs. Walgreens'

# Create formatting for unmatched values
unmatched = Spreadsheet::Format.new :weight => :bold, :color => :red

# Create a new row in the sheet, treat it like an Array!
# row(0) is the first line in the spreadsheet, usually
#  used as the header
outputSheet[0,0] = 'EmplID/Cardholder'
outputSheet[0,1] = 'Walgreens'
outputSheet[0,2] = 'PeopleSoft'

# Keep count of which spreadsheet row we are on
count = 1
emplid = ''
walgreensStatus = ''

# Iterate through spreadsheet starting at second row (first is 0)
walgreensSheet.each 1 do |row|
  
  # Get EMPLID from Walgreens Spreadsheet
  emplid = row[2].to_i
  puts "EMPLID: #{emplid}"
  outputSheet[count,0] = emplid

  # String object that contains the SQL that Fetches PeopleSoft HS Compliance 
  # Selects newest status per EMPLID
  mySQL = "

    select a.l_hs_compliant 
    from ps_l_hs_compliant A 
    where a.effdt = (select max(a1.effdt) from ps_l_hs_compliant A1
                     where A1.emplid = a.emplid)
    and a.emplid = '#{emplid}'

  "

  # Get status from Walgreens Spreadsheet
  walgreensStatus = row[14].to_s
  puts "Walgreens STATUS: #{walgreensStatus}"
  outputSheet[count,1] = walgreensStatus


  # Get Status from PeopleSoft
  cursor = db.parse(mySQL)

  cursor.exec()
  while r = cursor.fetch()
    puts "PeopleSoft STATUS: #{r[0]}"
    outputSheet[count,2] = r[0]
  end

  # Increment row count on the way out of the block
  count+=1

end

# Close database connection
db.logoff

# Write the spreadsheet to the filesystem
outputBook.write 'PSvWALGREENS.xls'

