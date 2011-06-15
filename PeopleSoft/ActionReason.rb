#!/usr/bin/ruby

#########################################################
# ActionReason.rb
#
# To gather Action/Reason codes and their statistics
#  into a spreadsheet
#
# 15Jun2011 - Michael Vera
#########################################################

require 'date'
require 'oci8'
require 'rubygems'
require 'spreadsheet'

# Set the object 'today' to the date using the Date class
today = Date.today

# Create database connection with the OCI8 Oracle driver
db = OCI8.new('psadm','PASSWORD','hrpd')

# Returns all ACTION & ACTION_REASON combos in PS_JOB
#  that don't exist in PS_ACTN_REASON_TBL
mySQL = "

select PS_JOB.ACTION, PS_JOB.ACTION_REASON 
from PS_JOB
minus
select PS_ACTN_REASON_TBL.ACTION, PS_ACTN_REASON_TBL.ACTION_REASON
from PS_ACTN_REASON_TBL

"

# Prepare the SQL and execute the statement
cursor = db.parse(mySQL)
cursor.exec()

# Create new spreadsheet instance
book = Spreadsheet::Workbook.new
sheet = book.create_worksheet 
sheet.name = 'My Spreadsheet'

# Keep count of which spreadsheet row we are on
count = 1

# Create a new row in the sheet, treat it like an Array!
# row(0) is the first line in the spreadsheet, usually
#  used as the header
sheet[0,0] = 'Action'
sheet[0,1] = 'Reason'
sheet[0,2] = 'Count'


# For each row that returns from the database cursor execution
while dbRow = cursor.fetch()

  # Row object for current Spreadsheet Row
  row = sheet.row(count)

  row[0] = dbRow[0]
  row[1] = dbRow[1]

  countSQL = "

select count(*) 
from ps_job a 
where a.action = '#{dbRow[0]}'
and a.action_reason = '#{dbRow[1].to_s}'

"  
  cursor2 = db.parse(countSQL)
  cursor2.exec()
  while countAR = cursor2.fetch()
    
    # Put the count in the third column of our current row 
    #   in the spreadsheet
    row[2] = countAR[0]

  end

 

  # Increment row count on the way out of the block
  count+=1

end

# Close database connection
db.logoff

# Write the spreadsheet to the filesystem
book.write 'ActionReason.xls'

