#!/usr/bin/ruby

###############################################################
# LifeInsuranceDiscrepancies.rb
#
# 18Dec2010 - Michael Vera
# 
# To create a spreadsheet report that contains those emplids
#  which need some sort of change in peopleSoft based on the
#  calculation rules required to compute Basic and Supplemental
#  Term Life Insurance.
###############################################################

require 'date'
require 'oci8'
require 'rubygems'
require 'spreadsheet'
require 'benchmark'


###########################
### User Defined Variables
###########################

# Turn on Debugging info
DEBUG 	= 1

# Set to 1 to print the entire data structure in CSV format:
CSV 	= 0

# Set Database here
myDB 	= 'hrpd'

# Specify Date for Plan Type EFFDT
#planDate = 'sysdate'
planDate = "TO_DATE('10/01/2010','MM/DD/YYYY')"


################################
### End User Defined Variables
################################


# Set the object 'today' to the date using the Date class
today = Date.today



###################################
### PeopleSoft Life&ADD Collection
###################################

# Connect to PeopleSoft
puts "Connecting to #{myDB} PeopleSoft Database" if DEBUG
db = OCI8.new('psadm','PASSWORD', myDB )
puts "Connected!" if DEBUG

# String object that contains the SQL that Fetches all eligible employees
# The salary info needs to be as of the first day of the fiscal year
getAll = "
select PS_JOB_1.EMPLID, 
       PS_JOB_1.EMPL_RCD,
       PS_PERSONAL_DATA.NAME,
       PS_PERSONAL_DATA.BIRTHDATE,
       PS_JOB_1.ANNUAL_RT
FROM   PS_JOB PS_JOB_1, 
       PS_PERSONAL_DATA 
WHERE  PS_JOB_1.EFFDT = (select max(PS_JOB_2.EFFDT) 
                             from PS_JOB PS_JOB_2 
                            where PS_JOB_1.EMPLID = PS_JOB_2.EMPLID
                              AND PS_JOB_1.EMPL_RCD = PS_JOB_2.EMPL_RCD
	  		      AND PS_JOB_1.EFFDT <= #{planDate}
			)
   AND PS_JOB_1.EFFSEQ = (select max(PS_JOB_3.EFFSEQ) 
                            from PS_JOB PS_JOB_3 
                            where PS_JOB_1.EMPLID = PS_JOB_3.EMPLID
                            AND PS_JOB_1.EMPL_RCD = PS_JOB_3.EMPL_RCD
                            AND PS_JOB_1.EFFDT = PS_JOB_3.EFFDT
			 ) 
   AND PS_JOB_1.COMPANY = 'EMP' 
   AND PS_JOB_1.FULL_PART_TIME = 'F' 
   AND PS_JOB_1.REG_TEMP = 'R' 
   AND PS_JOB_1.EMPL_STATUS in ('A', 'L', 'P', 'S')
   AND PS_JOB_1.EMPLID = PS_PERSONAL_DATA.EMPLID
   ORDER BY PS_JOB_1.EMPLID
"

puts "Getting all employees eligible for Life & ADD" if DEBUG

# Prepare the SQL, define the fields as incoming object types, and execute
cursor = db.parse(getAll)
cursor.define(4, Date) # Converts ncoming field to Date class
cursor.exec()


# Create array to hold all the employee info
#
# Reference implicitly: emplArray[#####] where ##### is emplid
#
# emplHash Structure:
# 	'emplid' 	  => EMPLID 	INTEGER
#	'name'		  => NAME 
#       'birthdate'       => BIRTHDATE
#	'age'		  => AGE Days since birthdate divided by 365.2425 rouned down
#	'annual_rate'	  => actual annual rate value
#	'effective_salary' => SALARY rounded up, no greater than 50K 
#	'20'		  => Current Plan Type 20 Value in PeopleSoft
#	'21'		  => Current Plan Type 21
#  	'2Z'		  => Current Plan Type 2Z
#       'pre_70_20'       => PT20 value from before age 70 (those over 70 only)
#       'pre_70_21'       => PT21 value from before age 70 (those over 70 only)
#       'pre_70_2Z'       => PT2Z value from before age 70 (those over 70 only)
#	'proposed_20'	  => Proposed New PT20 Value
#	'proposed_21'	  => Proposed New PT21 Value
#	'proposed_2Z'	  => Proposed New PT2Z Value
#       'total_supp'      => Total Supplemental Life +
#      				age < 70 => PT21 + PT2Z
#				age >=70 => (pre_70_21 + pre_70_2z)/2
#
#
# Reference array using EMPLID, e.g. emplArray[20840]['name'] => 'Vera,Michael'
# This will leave at least 10000 empty array references but speeds up searching

# emplArray[0] will be the template or structure definition
emplArray = []

# For each row that returns from the database cursor execution
while row = cursor.fetch()
  emplid = row[0].to_i
  empl_rcd = row[1].to_i
  name = row[2].to_s
  birthdate = row[3]
  age = ((today - birthdate)/365.2425).floor
  # Annual Rate is actual yearly rate
  annualRate = row[4].to_f
  # Salary is rounded up to the nearest 1000
  salary = ((annualRate/1000).ceil * 1000).to_i
  # Effective Salary is equal to or less than 50000
  (salary < 50000) ? (effectiveSalary = salary) : (effectiveSalary = 50000)

  # This hash holds the field name and the value
  emplHash = {
    'emplid' => emplid,
    'empl_rcd' => empl_rcd,
    'name' => name,
    'age' => age,
    'birthdate' => birthdate,
    'effective_salary' => effectiveSalary,
    'annual_rate' => annualRate
  }
   
  # Push the info hash into the employee array for faster processing later
  # Each employee's hash is stored in the emplid-th array element
  emplArray[emplid] = emplHash
  

end

### Print count of employees found
puts "Found #{emplArray.nitems} valid and eligible employees." if DEBUG


####################################
###### Go get current PT20, 21, 2Z
####################################

puts "Getting Plan Type amounts from PeopleSoft" if DEBUG

plan_types = '20', '21', '2Z'

### For each employee, load up the values effective as of on or before "planDate"
emplArray.each do |employee|

  next if employee.nil?

  # and for each plan_type
  plan_types.each do |plan_type|

    planTypeSQL = "
select  PS_LAB_1.FLAT_AMOUNT
from 		PS_LIFE_ADD_BEN PS_LAB_1
where	        PS_LAB_1.EMPLID  	= '#{employee['emplid']}'
and		PS_LAB_1.EMPL_RCD       = '#{employee['empl_rcd']}'
and		PS_LAB_1.PLAN_TYPE      = '#{plan_type}'
and		PS_LAB_1.BENEFIT_NBR    = '0'
and		PS_LAB_1.FACTOR_XSALARY = '0'
and		PS_LAB_1.COVERAGE_ELECT = 'E'
and PS_LAB_1.EFFDT =
	(select max(PS_LAB_2.EFFDT)
			from  PS_LIFE_ADD_BEN PS_LAB_2
			where PS_LAB_2.EMPLID       = PS_LAB_1.EMPLID
			and   PS_LAB_2.EMPL_RCD	    = PS_LAB_1.EMPL_RCD
			and   PS_LAB_2.PLAN_TYPE    = PS_LAB_1.PLAN_TYPE
			and   PS_LAB_2.BENEFIT_NBR  = PS_LAB_1.BENEFIT_NBR
			and   PS_LAB_2.FACTOR_XSALARY  = PS_LAB_1.FACTOR_XSALARY
			and   PS_LAB_2.EFFDT 	   <= sysdate )
"

    # Prepare the SQL, define the fields as incoming object types, and execute
    cursor = db.parse(planTypeSQL)
    cursor.exec()

    while amount = cursor.fetch()  
      employee[plan_type] = amount[0].to_i
    end
  
  end
end

##############################
### Go get all pre-70 values 
##############################

puts "Getting employees age 70+ maximum pre-70 Plan Type amounts from PeopleSoft" if DEBUG

emplArray.each do |employee|

  next if employee.nil?
  next if employee['age'] < 70

  ### Change the Plan type SQL from having a max effective date equal to or
  #     less than sysdate, to being equal to or less than when they turned 70
  # Replace sysdate with ADD_MONTHS(TO_DATE('1940-06-22','YYYY-MM-DD'), 839)
  # 12 * 70 = 839
  # 839 months to leave one spare month for an early effective date due to
  # a payroll cycle
  #
  # Default DATE format is "DD-MON-YY"
  #
  age70date = "ADD_MONTHS(TO_DATE('#{employee['birthdate']}','YYYY-MM-DD'), 839)"

  #puts "EMPLID: #{employee['emplid']}" if DEBUG

  # and for each plan_type
  plan_types.each do |plan_type|

    planTypeSQL = "
select  PS_LAB_1.FLAT_AMOUNT
from 		PS_LIFE_ADD_BEN PS_LAB_1
where	        PS_LAB_1.EMPLID  	= '#{employee['emplid']}'
and		PS_LAB_1.EMPL_RCD       = '#{employee['empl_rcd']}'
and		PS_LAB_1.PLAN_TYPE      = '#{plan_type}'
and		PS_LAB_1.BENEFIT_NBR    = '0'
and		PS_LAB_1.COVERAGE_ELECT = 'E'
and PS_LAB_1.EFFDT =
	(select max(PS_LAB_2.EFFDT)
			from  PS_LIFE_ADD_BEN PS_LAB_2
			where PS_LAB_2.EMPLID       = PS_LAB_1.EMPLID
			and   PS_LAB_2.EMPL_RCD	    = PS_LAB_1.EMPL_RCD
			and   PS_LAB_2.PLAN_TYPE    = PS_LAB_1.PLAN_TYPE
			and   PS_LAB_2.BENEFIT_NBR  = PS_LAB_1.BENEFIT_NBR
			and   PS_LAB_2.EFFDT 	   <= #{age70date} )
"

    # Prepare the SQL, define the fields as incoming object types, and execute
    cursor = db.parse(planTypeSQL)
    cursor.exec()

    while amount = cursor.fetch()  
      #puts "FLAT_AMOUNT=#{amount[0]}" if DEBUG
      pre70 = "pre_70_#{plan_type}"
      employee[pre70] = amount[0].to_i
    end
    
    #puts "\tPre-70 Plan Type #{plan_type} value: #{employee[pre70]}" if DEBUG
    #puts "\tCurrent Plan Type #{plan_type} value: #{employee[plan_type]}" if DEBUG
  
  end
end

#########################################################################
### Now we have all the PeopleSoft information necessary for Basic Life
#########################################################################


### Close database connection
#
puts "Closing database connection" if DEBUG
db.logoff

puts "emplArray contains #{emplArray.length} elements" if DEBUG
puts "emplArray contain #{emplArray.nitems} non-nil elements (i.e. valid and eligible employees)" if DEBUG



#############################
### Calculate Proposed PT20
#
puts "Calculating Proposed Plan Type 20 for all employees" if DEBUG

emplArray.each do |employee|

  next if employee.nil?

  if employee['20'].nil?
    puts "WARNING: EMPLID #{employee['emplid']} has an empty Plan Type 20!"
    next
  end


  ### Employees 70 and over => proposed_20 = (((employee['pre_70_20']/2000).ceil)*1000)
  #     (((employee['pre_70_20']/2000).ceil)*1000)
  #        Divide the pre-70 PT20 in half and move the decimal left three places
  #        Round that number up to next whole integer and move the decimal right three places
  #
  ### Under 70 employees    => proposed_20 = effective_salary
  employee['age'] < 70 ? employee['proposed_20']=employee['effective_salary'] : employee['proposed_20']=(((employee['pre_70_20'].to_f/2000).ceil)*1000).to_i
  
end
#
### proposed_20 is now set and is the law
#########################################





#########################################
### Calculate Supplemental
# 
puts "Calculating Supplemental Insurance for all employees" if DEBUG

emplArray.each do |employee|

  next if employee.nil?

  ### If Plan Types 21 and 2Z are empty, there is no supplemental insurance
  next if ((employee['21'].nil?) && (employee['2Z'].nil?))

  ### Calculate Current Supplemental under age 70
  if employee['age'] < 70

    employee['total_supp'] = employee['21'].to_i + employee['2Z'].to_i

    # Next if PT20 is nil
    next if employee['20'].nil?

    # Next employee if employee supplemental is 0
    next if employee['total_supp'] == 0

    # If PT20 = 50000, Proposed PT21 = nil & PT2Z = total_supp
    if employee['proposed_20'] == 50000

      employee['proposed_2Z'] = employee['total_supp']
      next

    # If PT20 + total_supp <= 50000, PT21 = total_supp
    elsif ( (employee['proposed_20'] + employee['total_supp']) < 50000 )

      employee['proposed_21'] = employee['total_supp']
      next

    elsif (employee['20'] > 50000)

      puts "ERROR: #{employee['emplid']} has a Plan Type 20 greater than 50000!"
      next

    else

      employee['proposed_21'] = 50000 - employee['proposed_20']
      employee['proposed_2Z'] = employee['total_supp'] - employee['proposed_21']

    end
    


  ### Calculate age 70+ Total Supplemental which is half the last PT21 & PT2Z pre-70
  else

    employee['total_supp'] = 
      (((((employee['pre_70_21'].to_i + employee['pre_70_2Z'].to_i).to_f)/2000).ceil)*1000).to_i

    # Employee didn't have supplemental before age 70!
    next if employee['total_supp'] == 0

    # If PT20 + total_supp < 50000, PT21 = total_supp
    if ( (employee['proposed_20'] + employee['total_supp']) < 50000 )

      employee['proposed_21'] = employee['total_supp']
      next

    end

    # Proposed PT21 = 50000 - Proposed PT20
    employee['proposed_21'] = 50000 - employee['proposed_20'].to_i

    # Proposed PT2Z = total_supp - Proposed PT21
    employee['proposed_2Z'] = employee['total_supp'] - employee['proposed_21']

  end
  
end
#
### total_supp is now set
#########################################


### Print the entire emplArray in CSV Format if CSV object is defined
#
if (CSV)
  outFile = File.new("LifeInsuranceDiscrepancies.csv", 'w')
  puts "Printing emplArray to output file"

  outFile.puts("EmplID|EmplRcd|Name|Birthdate|Age|AnnualRate|EffectiveSalary|PT20|PT21|PT2Z|Pre70PT20|Pre70PT21|Pre70PT2Z|ProposedPT20|ProposedPT21|ProposedPT2Z")
  emplArray.each do |e|
    next if e.nil?
    # Now we have a Hash object called 'employee' which is the employee data

    next if ((e['20'] == e['proposed_20']) && 
             (e['21'] == e['proposed_21']) &&
             (e['2Z'] == e['proposed_2Z']))

    outFile.puts("#{e['emplid'].to_s}|#{e['empl_rcd']}|#{e['name'].to_s}|#{e['birthdate'].to_s}|#{e['age'].to_s}|#{e['annual_rate'].to_s}|#{e['effective_salary'].to_s}|#{e['20'].to_s}|#{e['21'].to_s}|#{e['2Z'].to_s}|#{e['pre_70_20'].to_s}|#{e['pre_70_21'].to_s}|#{e['pre_70_2Z'].to_s}|#{e['proposed_20'].to_s}|#{e['proposed_21'].to_s}|#{e['proposed_2Z'].to_s}" )
  end
end










######  #    #     #     #####
#        #  #      #       #
#####     ##       #       #
#         ##       #       #
#        #  #      #       #
######  #    #     #       #
puts "I was told to exit early!"
exit


















###########################
### Output to Spreadsheet 
###########################

# Create new spreadsheet instance
book = Spreadsheet::Workbook.new


### One "Tab" or "Worksheet" of the spreadsheet is for
#     those whose Plan Type 20 does not equal effective salary
sheet1 = book.create_worksheet 
sheet1.name = 'Increase Plan Type 20'

### The next Tab/Worksheet is where PT20 + PT21 < 50000 && 2Z is NOT NULL
#
sheet2 = book.create_worksheet
sheet2.name = 'Adjust Plan Type 21'

### Write the header row
#
sheet1.row(0).concat %w{EmplID Name Age AnnualRate CurrentPT20 ProposedPT20}
sheet2.row(0).concat %w{EmplID Name Age AnnualRate CurrentPT20 CurrentPT21 CurrentPT2Z ProposedPT20 ProposedPT21 ProposedPT2Z}

# Keep track of which spreadsheet row we are on
sheet1count = 1
sheet2count = 1

# Define hash outside the block to increase performance
info = {}
employee = {}
pt20changes = 0 # Count of proposed pt20 changes
pt21changes = 0 # Count of proposed pt21 changes
pt2Zchanges = 0 # Count of proposed pt2Z changes
blank2Z = 0	# Total count of blank 2Z values
increase21decrease2Z = 0 # Total count of 21<-2Z shifts
decrease21increase2Z = 0 # Total count of 21->2Z shifts
x = 0		# X Factor

#puts "Loading #{emplArray.nitems} emplArray elements into report/spreadsheet"
# Load each element of the emplArray into 'info'



emplArray.each do |employee|

  ### Skip the empty emplArray
  next if employee.nil?

  ### Doug Thomas actually uses the salary multplier for calculating
  #     COL provided Basic Term Life, so leave him out
  #
  next if employee['emplid'] == '18443'

  ### Leave out those over 70
  next if employee['age'] > 70

  ### If the Plan type 20 (COL supplied basic life)
  #     is LESS THAN the effective salary, PT20 needs an adjustment
  #     so print onto sheet one
  if ( employee['20'].to_i < employee['effective_salary'].to_i )

    ### effective_salary becomes Proposed PT20
    #
    employee['proposed_20'] = employee['effective_salary']
    pt20changes+=1

    sheet1.row(sheet1count).push(employee['emplid'])
    sheet1.row(sheet1count).push(employee['name'])
    sheet1.row(sheet1count).push(employee['age'])
    sheet1.row(sheet1count).push(employee['annual_rate'])
    sheet1.row(sheet1count).push(employee['20'])
    sheet1.row(sheet1count).push(employee['proposed_20'])

    # Increment row count on the way out of the block
    sheet1count+=1
   

  end

  ### Go to next Employee if 2Z is not defined
  #     This assumes a lack of a 2Z value means the total supplemental
  #     is at its max
  #
  if (employee['2Z'].to_s == '')
    blank2Z+=1
    next
  end

  ### If Plan Type 20 + Plan Type 21 < 50000
  #     AND Plan Type 2Z is NOT NULL
  #     => Plan Type 21 will need to be increased by X
  #        Plan Type 2Z will need to be decreased by X
  #   X = 50000-(PT20+PT21)
  #
  #     For all x < 0, pt20 and pt21 exceed IRS max 50000
  #     for x = 0, pt20 and pt21 equal 50000
  #     For x > 0, PT21 could increase by X and PT2Z decrease by X
  #
  # EmplID Name Age AnnualRate CurrentPT20 CurrentPT21 CurrentPT2Z ProposedPT20 ProposedPT21 ProposedPT2Z

  ### Use employee['proposed_20'] if it exists, otherwise use employee['20']  
  #
  if (employee['proposed_20'])
    x = (50000 - (employee['proposed_20'].to_i + employee['21'].to_i) )
  else
    x = (50000 - (employee['20'].to_i + employee['21'].to_i) )
  end
  
  if (x == 0) # PT20 + PT21 = 50000, perfect
    next
  end

  ### If a positive X Factor, and does not have a blank 2Z value
  if ((x > 0) && !(employee['2Z'].to_s == ''))
    #puts "Employee, emplid #{employee['emplid']}, has a Plan Type 20 and Plan Type 21 value  that is below the 50000 limit by #{x} dollars, and there exists a 2Z value, #{employee['2Z']}"
    employee['proposed_21'] = employee['21'].to_i + x
    employee['proposed_2Z'] = employee['2Z'].to_i - x
    increase21decrease2Z+=1
  end

  ### These exceed the 50000 maximum, so the PT21 will need to decrease
  #
  if (x < 0)
    #puts "Employee, emplid #{employee['emplid']}, has a Plan Type 20 and Plan type 21 that exceeds 50000 IRS maximum by #{x} dollars"
    employee['proposed_21'] = employee['21'].to_i - x
    employee['proposed_2Z'] = employee['2Z'].to_i + x
    decrease21increase2Z+=1
  end

  
      


end


### Statistics
#
puts "PT20 proposed changes: #{pt20changes}"
puts
puts "PT21 Decrease with PT2Z Increase: #{decrease21increase2Z}"
puts "PT21 Increase with PT2Z Decrease: #{increase21decrease2Z}"
puts "PT2Z empty values:\t#{blank2Z}"

###
puts "Writing spreadsheet output to filesystem"
# Write the info to the filesystem
book.write 'LifeInsuranceDiscrepancies.xls'



