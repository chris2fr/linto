BEGIN {
    IGNORECASE = 1
    RS = "\n"
    OFS = ";"
    
  if (format == "")
    output_format = "1" # changer pour les formats de sorti 1, 2 ou 3
  n = split("key abstract author date edition file howpublished keywords language month note number organization publisher shorthand shorthand2 title type url urldate xacronym xcontentmd xcounter xdatetime xduplicate xeditionorig xeditionorig2 xeditionorig3 xfileorig xkeyorig xkeyorig2 xkeyorig3 xkeyorig4 xnumberorig xshorthandorig xshorthandorig2 xtheme xtime xtype xtypeorig year yearnum monthnum yearmonth monthname daynum", fld, " ")

  # Map field name -> position, so the theme filter doesn't rely on a
  # hardcoded index and stays correct if the field list above changes.
  for (i = 1; i <= n; i++) {
    fldidx[fld[i]] = i
  }
}

NR>1{
  RS = "\n"
  OFS = ";"
  split($0,f,/;/)

  f[fldidx["author"]] = gensub(/[{}]/,"","g",f[fldidx["author"]])

  f[fldidx["yearnum"]] = get_yearnum(f[fldidx["date"]])
  f[fldidx["monthnum"]] = get_monthnum(f[fldidx["date"]])
  f[fldidx["yearmonth"]] = get_yearmonth(f[fldidx["date"]])
  f[fldidx["monthname"]] = get_monthname(f[fldidx["date"]])
  f[fldidx["daynum"]] = get_daynum(f[fldidx["date"]])
  
  if (output_format == "1")
    output1(f, fldidx)
  if (output_format == "2")
    output2(f, fldidx)
  if (output_format == "3")
    output3(f, fldidx)
}

function get_yearnum(date) {
  n = split(date,datehyphens,"-")
  ret = datehyphens[1]
  return ret
}
function get_yearmonth(date) {
  ret = get_yearnum(date) "-" get_monthnum(date)
  ret = gensub(/^-/,"...","g",ret)
  return ret
}

function get_monthnum(date) {
  n = split(date,datehyphens,"-")
  ret = datehyphens[2]
  ret = gensub(/^$/,"...","g",ret)
  return ret
}
function get_monthname(date) {
  n = split(date,datehyphens,"-")
  ret = datehyphens[2]
  if (ret == "01")
    ret = "jan."
  if (ret == "02")
    ret = "feb."
  if (ret == "03")
    ret = "mars"
  if (ret == "04")
    ret = "avril"
  if (ret == "05")
    ret = "mai"
  if (ret == "06")
    ret = "juin"
  if (ret == "07")
    ret = "juillet"
  if (ret == "08")
    ret = "août"
  if (ret == "09")
    ret = "sep."
  if (ret == "10")
    ret = "oct."
  if (ret == "11")
    ret = "nov."
  if (ret == "12")
    ret = "dec."
  ret = gensub(/^$/,"...","g",ret)
  return ret
}

function get_daynum(date) {
  n = split(date,datehyphens,"-")
  ret = datehyphens[3]
  ret = gensub(/^0/,"","g",ret)
  ret = gensub(/^1$/,"1er","g",ret)
  ret = gensub(/^0$/,"...","g",ret)
  ret = gensub(/^$/,"...","g",ret)
  return ret
}

function get_dateparts(date) {
  dateparts["yearnum"] = null
  dateparts["monthnum"] = null
  dateparts["yearmonth"] = null
  dateparts["monthname"] = null
  dateparts["daynum"] = null
  n = split(date,datehyphens,"-")
  dateparts["yearnum"] = datehyphens[1]
  dateparts["monthnum"] = datehyphens[2]
  dateparts["yearmonth"] = dateparts["yearnum"] "-" dateparts["monthnum"]
  # dateparts["monthname"] = "..."
  if (datehyphens["monthnum"] == "01")
    dateparts["monthname"] = "jan."
  if (datehyphens["monthnum"] == "02")
    dateparts["monthname"] = "feb."
  if (datehyphens["monthnum"] == "03")
    dateparts["monthname"] = "mars"
  if (datehyphens["monthnum"] == "04")
    dateparts["monthname"] = "avril"
  if (datehyphens["monthnum"] == "05")
    dateparts["monthname"] = "mai"
  if (datehyphens["monthnum"] == "06")
    dateparts["monthname"] = "juin"
  if (datehyphens["monthnum"] == "07")
    dateparts["monthname"] = "juillet"
  if (datehyphens["monthnum"] == "08")
    dateparts["monthname"] = "août"
  if (datehyphens["monthnum"] == "09")
    dateparts["monthname"] = "sep."
  if (datehyphens["monthnum"] == "10")
    dateparts["monthname"] = "oct."
  if (datehyphens["monthnum"] == "11")
    dateparts["monthname"] = "nov."
  if (datehyphens["monthnum"] == "12")
    dateparts["monthname"] = "dec."
  dateparts["daynum"] = gensub(/^0/,"","g",datehyphens[3])
  dateparts["daynum"] = gensub(/^1$/,"1er","g",dateparts["daynum"])
  dateparts["daynum"] = gensub(/^0$/,"...","g",dateparts["daynum"])
  if (dateparts["daynum"] == "")
    dateparts["daynum"] = "..."

  if (dateparts["yearnum"] != prevyear) {
    print_year_heading(output_format,dateparts["yearnum"])
    prevyear = dateparts["yearnum"]
  }
  if (dateparts["monthname"] != prevdateparts["monthname"]) {
    print_month_heading(output_format, dateparts["monthname"], dateparts["yearnum"])
    prevdateparts["monthname"] = dateparts["monthname"]
  }
  return dateparts
}

function print_year_heading(output_format, y) {
  if (output_format == "1")
    output1_print_year_heading(y)
  if (output_format == "2")
    output2_print_year_heading()
  if (output_format == "3")
    output3_print_year_heading()
}


function print_month_heading(output_format, mname, y) {
  if (output_format == "1")
    output1_print_month_heading(mname, y)
  if (output_format == "2")
    output2_print_month_heading()
  if (output_format == "3")
    output3_print_month_heading()
}

function output1_print_year_heading(y) {
  printf "**%s**\n\n", y
}

function output1_print_month_heading(mname, y) {
  printf "*%s* **%s**\n\n", mname, y
}

function output2_print_year_heading(y) {
}

function output2_print_month_heading(mname, y) {
}

function output3_print_year_heading(y) {
}

function output3_print_month_heading(mname, y) {
}

function output1(f, fldidx) {
  type = f[fldidx["type"]]
  xtime = f[fldidx["xtime"]]
  number = f[fldidx["number"]]
  author = f[fldidx["author"]]
  organization = f[fldidx["organization"]]
  publisher = f[fldidx["publisher"]]
  howpublished = f[fldidx["howpublished"]]
  title = f[fldidx["title"]]
  key = f[fldidx["key"]]
  xacronym = f[fldidx["xacronym"]]
  keywords = f[fldidx["keywords"]]
  edition = f[fldidx["edition"]]
  note = f[fldidx["note"]]
  annote = f[fldidx["annote"]]
  abstract = f[fldidx["abstract"]]
  url = f[fldidx["url"]]
  lenurl = length(url)
  yearnum = get_yearnum(f[fldidx["date"]])
  monthnum = get_monthnum(f[fldidx["date"]])
  yearmonth = get_yearmonth(f[fldidx["date"]])
  monthname = get_monthname(f[fldidx["date"]])
  daynum = get_daynum(f[fldidx["date"]])

  printf "\n%s *%s* **%s** [%s]", daynum, monthname, yearnum, type
  if (xtime)
   printf " à %s ", xtime
  else
    printf " %s ", number
  printf "de *%s* ", author
  if (organization)
    printf " (%s) ", organization
  if (publisher)
    printf " par %s ", publisher
  if (howpublished)
    printf " via %s ", howpublished
  printf "\\\n***%s***", title
  printf "\\\n[@%s] %s", key, keywords
  # printf "\\\n[@%s] %s %s [\\@%s]", key, xacronym, keywords, key
  # printf "\\\nƒ [%s](%s)", edition, file
  if (note)
    printf "\\\n¶ *%s*", note
  if (annote)
    printf "\\\n¶ *%s*", annote
  if (abstract)
    printf "\\\n¶ *%s*", abstract
  lenurl = length(url)
  if (lenurl > 0 && url)
    printf "\\\nφ %s", url
    # if (length(url) > 96)
    #   printf "φ [%s...%s](%s)\n", substr(url,0,24),substr(url,length(url)-24,24),url
    # else
    #   printf "φ [%s](%s)\n", url, url
  printf "\n"
}

function output2(f, fldidx) {
  date = f[fldidx["date"]]
  author = f[fldidx["author"]]
  type = f[fldidx["type"]]
  key = f[fldidx["key"]]
  title = f[fldidx["title"]]
  edition = f[fldidx["edition"]]
  printf "- %s %s [%s] [@%s]\\\n  ***%s***\\\n  [%s]\\\n[\\@%s]\\\n", date, author, type, key, title, edition, key
  # printf "- %s [@%s] %s [%s]\n  *%s*\n", f[1], f[2], f[3], f[6], f[4]
  # ·
}

function output3(f, fldidx) {
  date = f[fldidx["date"]]
  title = f[fldidx["title"]]
  author = f[fldidx["author"]]
  edition = f[fldidx["edition"]]
  type = f[fldidx["type"]]
  shorthand = f[fldidx["shorthand"]]
  key = f[fldidx["key"]]

  printf "- - %s\n", date
  printf "  - ***%s***\n", title
  # printf "\n"
  printf "- - %s\n",  author
  printf "  - [%s]\n", edition
  # printf "\n"
  printf "- - [%s] (%s)\n", type, shorthand
  printf "  - [\\@%s]\n", key
  printf "\n"
}

function output1_begin (fld) {

}
function output2_begin (fld) {
  
}
function output3_begin (fld) {
  n = length(fld)
    for (i = 1; i <= n; i++) printf ";%s", fld[i]
    printf "\n\n"
    printf "::: {.list-table .borderless tbl-colwidths=\"[20,80]\" aligns=\"l,l\" header-rows=0}\n"
}

function output1_end () {

}
function output2_end () {
  
}
function output3_end () {
  printf "\n:::"
}

END {
  if (output_format == "1")
    output1_end()
  if (output_format == "2")
    output2_end()
  if (output_format == "3")
    output3_end()
}