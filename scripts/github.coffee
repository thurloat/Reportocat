class GitHubPresenter extends Presenter
  
  @PRESS =
    display: 'GitHubDisplayType'
  
  @INJECT =
    eventBus: 'getEventBus'
    logger: 'getLogger'
    service: 'getService'
    loginPresenter: 'getLoginPresenter'
    repoListPresenter: 'getRepoListPresenter'
    
  onBind: ->
    
    @registerHandler "click", @display.getLogoutButton(), (event) =>
      console.log('logout clicked')
      @service.logout()
      
      @makeForward @loginPresenter, @repoListPresenter
    
    # After successful login attempt, show the repo list presenter.
    @registerHandler "loginSuccess", true, (event) =>
      @makeForward @repoListPresenter, @loginPresenter
      
    # Show login page if required.
    if not @service.loggedIn()
      # OAuth borked, Display the oauth start page.
      @makeForward @loginPresenter, @repoListPresenter
    else
      # continue with workflow.
      # check to see if a repo has been selected to log issues to.
      # TODO
      @makeForward @repoListPresenter, @loginPresenter

  makeForward: (toShow, toHide) ->
    toHide.unbind()
    toShow.bind()
    @display.replaceWidget toShow.getDisplay().asWidget()
      
class GitHubDisplay extends Display

  constructor: ->
    @appPanel = $ '<div id="appPanel"></div>'
    @appPanelContent = $ '<div/>'
    
    @headerPanel = $ '<div id="header"><h1>Reportocat</h1></div>'
    @logoutButton = $ '<a href="javascript:void(0);">Logout</a>'
    @logoutButton.appendTo @headerPanel
    
    @headerPanel.appendTo @appPanel
    @appPanelContent.appendTo @appPanel
    
    $('<h3>GitHub Display</h3>').appendTo @appPanelContent
  
  asWidget: -> @appPanel[0]
  
  getLogoutButton: -> @logoutButton[0]
  
  replaceWidget: (widget) ->

    @appPanelContent.empty()
    @appPanelContent.append widget

class LoginPresenter extends Presenter
  
  @PRESS =
    display: 'LoginDisplayType'
  
  @INJECT =
    eventBus: 'getEventBus'
    logger: 'getLogger'
    service: 'getService'
  
  onBind: ->
  
    @registerHandler "click", @display.getOAuthButton(), (event) =>
      # OAuth flow button clicked. 
      @service.logout()
      @service.startAuth()
  
  
  
class LoginDisplay extends Display
  
  constructor: ->
    @loginPanel = $ '<div/>'
    
    @oauthButton = $ '<a href="javascript:void(0);">OAuth Go!</a>'
    @oauthButton.appendTo @loginPanel
  
  getOAuthButton: -> @oauthButton[0]
  
  asWidget: -> @loginPanel[0]
  

class RepoListPresenter extends Presenter
  
  @PRESS =
    display: 'RepoListDisplayType'
  
  @INJECT =
    eventBus: 'getEventBus'
    logger: 'getLogger'
    service: 'getService'
    
  onBind: ->
    @repos = []
    
    @registerHandler "repoSelected", true, (event) =>
      # dont do anything
      console.log("Repo Selected")
      
    # Get the repos to show
    @service.getUserRepoList (repos) =>
      console.log repos
      # convertedRepos = (new GithubRepo repo for repo in repos)
      @addRepo repo for repo in repos
      console.log @repos

  addRepo: (repo) ->
    repoListItemPresenter = @esm.create RepoListItemPresenter
    repoListItemPresenter.setRepo repo
    repoListItemPresenter.bind()
    
    @display.addRepo repoListItemPresenter.getDisplay().asWidget()
    @repos.push(repo)
    
class RepoListDisplay extends Display
  
  constructor: ->
    @listItems = []
    
    @panel = $ '<div id="repoListDisplay"><h2>Select a Repository</h2><p>Issues will be logged to the selected Repo for this session.</p></div>'
    @list = $ '<ul></ul>'
    
    @list.appendTo @panel
  
  asWidget: -> @panel[0]
  
  addRepo: (repoWidget) ->
    @list.append repoWidget
    @listItems.push repoWidget
    
  clearRepos: ->
    @listItems = []
    @list.empty()
    

class RepoListItemPresenter extends Presenter
  @PRESS =
    display: 'RepoListItemDisplayType'
    
  @INJECT =
    eventBus: 'getEventBus'
    
  onBind: ->
    if @repo
      @display.setName @repo.name
      @display.setSiteLink @repo.siteUrl
      @display.setSiteText @repo.siteUrl
    
  setRepo: (@repo) ->
  
class RepoListItemDisplay extends Display
  constructor: ->
    @panel = $ '<li></li>'

    @repoNameLabel = $ '<span></span>'
    @repoSiteLink = $ '<a href="javascript:void(0);"></a>'
    
    @repoNameLabel.appendTo @panel
    @repoSiteLink.appendTo @panel

  getNameLabel: -> @repoNameLabel
  getSiteLink: -> @repoSiteLink

  setName: (text) -> @repoNameLabel.text text
  setSiteLink: (link) -> @repoSiteLink.attr href: link
  setSiteText: (text) -> @repoSiteLink.text text

  asWidget: -> @panel[0]

class GitHubRepo
  constructor: (@json) ->
    @apiUrl = @json.url
    @siteUrl = @json.html_url
    @owner = new GitHubUser @json.owner
    @name = @json.name
    @description = @json.description
    @homepage = @json.homepage
    @language = @json.language
    @private = @json.private
    @fork = @json.fork
    @forks = @json.forks
    @watchers = @json.watchers
    @size = @json.size
    @openIssues = @json.open_issues
    @pushedAt = @json.pushed_at
    @createdAt = @json.created_at
    
    
class GitHubUser
  constructor: (@json) ->
    @id = @json.id
    @username = @json.login
    @gravatarUrl = @json.gravatar_url
    @githubUrl = @json.url
  
  
class GitHubService
  
  @PRESS = 
    oauth: 'getOAuth'
  
  @INJECT =
    eventBus: 'getEventBus'
    logger: 'getLogger'
  
  constructor: (@oauth) ->
    @api_root = "https://api.github.com"
    
  logout: -> @oauth.clearTokens()

  startAuth: -> 
    @oauth.authorize =>
      @eventBus.fire "loginSuccess", true
      
  getUserRepoList: (callback) ->
    @oauth.sendSignedRequest @api_root + '/user/repos', (responseText, xhr) =>
      jsonResult = $.parseJSON responseText
      repos = (new GitHubRepo repo for repo in jsonResult)
      callback repos
        
  loggedIn: -> @oauth.hasToken()

class Application
  
  esp = new EspressoMachine
  eventBus = new EventBus
  logger = new Logger
  hasRun = false
  
  run: ->
    if hasRun
      return
    hasRun = true
    
    # register some base services with the Espresso Machine
    esp.register('getEventBus', -> eventBus)
    esp.register('getLogger', -> logger)
    esp.register('getRootPanel', -> $('#application'))
    
    # create singleton the display classes and register with the Espresso Machine
    ghDisplay = new GitHubDisplay
    loginDisplay = new LoginDisplay
    repoListDisplay = new RepoListDisplay
    
    esp.register 'GitHubDisplayType', -> ghDisplay
    esp.register 'LoginDisplayType', -> loginDisplay
    esp.register 'RepoListDisplayType', -> repoListDisplay
    
    # create the factory display classes and register them with the Espresso Machine.
    esp.register 'RepoListItemDisplayType', -> new RepoListItemDisplay  
    
    # reach into the background.html page for the oauth info.
    backgroundPage = chrome.extension.getBackgroundPage()
    # register the chrome extension's oauth with the Espresso Machine
    esp.register('getOAuth', -> backgroundPage.oauth)
    
    # press the GitHub service which relies on the oauth.
    gh = esp.create(GitHubService)
    
    # Register the github service.
    esp.register 'getService', -> gh

    loginPresenter = esp.create LoginPresenter
    esp.register 'getLoginPresenter', -> loginPresenter
    
    repoListPresenter = esp.create RepoListPresenter
    esp.register 'getRepoListPresenter', -> repoListPresenter
    
    ghPresenter = esp.create GitHubPresenter
    ghPresenter.bind()
    
    esp.getRootPanel().empty()
    esp.getRootPanel().append ghPresenter.getDisplay().asWidget()
  
    
@ready =>
  @app = new Application()
  @app.run()