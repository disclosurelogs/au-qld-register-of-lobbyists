require 'scraperwiki'
require 'open-uri'
require 'yaml'
class Array
  def to_yaml_style
    :inline
  end
end

html = ScraperWiki.scrape("http://lobbyists.integrity.qld.gov.au/register-details/list-companies.aspx")

# Next we use Nokogiri to extract the values from the HTML source.

require 'nokogiri'
page = Nokogiri::HTML(html)

baseurl = "http://lobbyists.integrity.qld.gov.au/register-details/"
urls = page.search('.demo li a').map {|a| a.attributes['href']}

# resume from the last incomplete url if the scraper was terminated
resumeFromHere = false
last_url = ScraperWiki.get_var("last_url", "")
if last_url == "" then resumeFromHere = true end

lobbyists = urls.map do |url|
  url = "#{baseurl}/#{url}"

  if url == last_url then resumeFromHere = true end
  if resumeFromHere
  ScraperWiki.save_var("last_url", url) 

  puts "Downloading #{url}"
begin
  lobbypage = Nokogiri::HTML(ScraperWiki.scrape(url))
  
  #thanks http://ponderer.org/download/xpath/ and http://www.zvon.org/xxl/XPathTutorial/Output/
  employees = []
  clients = []
  owners = []
  lobbyist_firm = {}
  
  companyABN=lobbypage.xpath("//tr/td/strong[text() = 'A B N:']/ancestor::td/following-sibling::node()/span/text()")
  companyName=lobbypage.xpath("//strong[text() = 'BUSINESS ENTITY NAME:']/ancestor::td/following-sibling::node()[2]/span/text()").first
  tradingName=lobbypage.xpath("//strong[text() = 'TRADING NAME:']/ancestor::td/following-sibling::node()[2]/span/text()").first
  lobbyist_firm["business_name"] = companyName.to_s
  lobbyist_firm["trading_name"] = tradingName.to_s
  lobbyist_firm["abn"] =  companyABN.to_s.gsub(' ','')
  lobbypage.xpath("//strong[text() = 'CURRENT THIRD PARTY CLIENT DETAILS:']/ancestor::p/following-sibling::node()[4]//tr/td[1]/text()").each do |client|
    clientName = client.content.strip
    if clientName.empty? == false and clientName.class != 'binary'
      clients << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => clientName }
    end
  end
  lobbypage.xpath("//strong[text() = 'PREVIOUS THIRD PARTY CLIENT DETAILS:']/ancestor::p/following-sibling::node()[4]//td/text()").each do |client|
    clientName = client.content.strip
    if clientName.empty? == false and clientName.class != 'binary'
      clients << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => clientName }
    end
  end
  lobbypage.xpath("//table[following::comment() = ' EndCompanyOwner'][3]//td").each do |owner|
    ownerName = owner.content.strip
    if ownerName.empty? == false and ownerName.class != 'binary'
      owners << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => ownerName }
    end
  end
  lobbypage.xpath("//strong[text() = 'DETAILS OF ALL PERSONS OR EMPLOYEES WHO CONDUCT LOBBYING ACTIVITIES:']/ancestor::p/following-sibling::node()[4]//tr//td[1]/text()").each do |employee|
    employeeName = employee.content.gsub("  ", " ").strip
    if employeeName.empty? == false and employeeName.class != 'binary'
      employees << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => employeeName}

    end
  end

  ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=employees, table_name="lobbyists")
  ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=clients, table_name="lobbyist_clients")
  ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=owners, table_name="lobbyist_firm_owners")
  ScraperWiki.save(unique_keys=["business_name","abn"],data=lobbyist_firm, table_name="lobbyist_firms")
     rescue Timeout::Error => e
        print "Timeout on #{url}"
     end
  end
end
ScraperWiki.save_var("last_url", "")