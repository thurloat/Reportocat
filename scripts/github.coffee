## Reportocat
# *Reportocat* is a Chrome Extension to allow you to quickly log issues to GitHub projects in sessions.
#
# The application is written in CoffeeScript using the **Americano** MVP Framework.


## GitHubPresenter ##
# This is the Main Presenter for the Reportocat application. This controls
# the workflow between views and is responsible for maintaining overall
# state.
class GitHubPresenter extends Presenter
  
  @PRESS =
    display: 'GitHubDisplayType'
  
  @INJECT =
    eventBus: 'getEventBus'
    logger: 'getLogger'
    service: 'getService'
    loginPresenter: 'getLoginPresenter'
    repoListPresenter: 'getRepoListPresenter'
    startSessionPresenter: 'getStartSessionPresenter'
    
  onBind: ->
    @presenters = [@loginPresenter, @repoListPresenter, @startSessionPresenter]
      
    @registerHandler "click", @display.getLogoutButton(), (event) =>
      console.log('logout clicked')
      @service.logout()
      
      @makeForward @loginPresenter
    
    # After successful login attempt, show the repo list presenter.
    @registerHandler "loginSuccess", true, (event) =>
      @makeForward @repoListPresenter
      
    @registerHandler "newSession", true, (event) =>
      @makeForward @repoListPresenter
    
    # Show login page if required.
    if not @service.loggedIn()
      # OAuth borked, Display the oauth start page.
      @display.hideLogoutButton()
      @makeForward @loginPresenter
    else
      if not @service.inSession()
        # Show the 'welcome' / 'start new session' screen
        @makeForward @startSessionPresenter
      else
        # continue with workflow.
        # check to see if a repo has been selected to log issues to.
        # TODO
        @makeForward @repoListPresenter

  makeForward: (toShow) ->
    toShow.ensureBound()
    @display.replaceWidget toShow.getDisplay().asWidget()

## GitHubDisplay ##
# This is the container for all of the views within the application.
# It's pretty much just a wrapper for the views of the sub-presenters to live.
class GitHubDisplay extends Display

  constructor: ->
    @appPanel = $ '<div id="appPanel"></div>'
    @appPanelContent = $ '<div/>'
    
    @headerPanel = $ '<div id="header"><img src="/reportocat.png" /><h1>Reportocat</h1></div>'
    @logoutButton = $ '<a href="javascript:void(0);">Logout</a>'
    @logoutButton.appendTo @headerPanel
    
    @headerPanel.appendTo @appPanel
    @appPanelContent.appendTo @appPanel
    
    $('<h3>GitHub Display</h3>').appendTo @appPanelContent
  
  asWidget: -> @appPanel[0]
  
  getLogoutButton: -> @logoutButton[0]
  hideLogoutButton: -> @logoutButton.hide()
  replaceWidget: (widget) ->

    @appPanelContent.empty()
    @appPanelContent.append widget

## LoginPresenter ##
# The Login Presenter handles the login process through oauth, as well as
# displaying the login view to the user.
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
  
## LoginDisplay ##
# Displays the OAuth button, and instructions to the user.
class LoginDisplay extends Display
  
  constructor: ->
    @loginPanel = $ '''
      <div id="loginDisplay">
        <h2>Authorization</h2>
        <p>In order to use the gadget, you must first do the OAuth Dance!</p>
      </div>'''
    
    @oauthButton = $ '<a href="javascript:void(0);">Go, OAuth Go!</a>'
    @oauthButton.appendTo @loginPanel
  
  getOAuthButton: -> @oauthButton[0]
  
  asWidget: -> @loginPanel[0]

## StartSessionPresenter ##
# This bad boy gets the session workflow started anew
class StartSessionPresenter extends Presenter
  
  @PRESS = 
    display: 'StartSessionDisplayType'
    
  @INJECT = 
    eventBus: 'getEventBus'
    
  onBind: ->
    @registerHandler "click", @display.getStartSessionButton(), (event) =>
      @eventBus.fire "newSession" 

## StartSessionDisplay ##
# Displays instructions, as well as the action button for the user to start the
# session.
class StartSessionDisplay extends Display

  constructor: ->
    @sessionPanel = $ '''
      <div id="startSessionDisplay">
        <h2>Start a new Session</h2>
        <p>I\'m going to impose some workflow on you. In order to start 
        reporting issues to a repo, you must first start a session. A 
        Session contains information about the Repo you want to report to, as
         well as statistics on your sessions so you can flex your QA muscles 
         later.
        </p>
      </div>'''
    @startSessionButton = $ '''<a href="javascript:void(0);">Start Session</a>'''
    @startSessionButton.appendTo @sessionPanel
  
  getStartSessionButton: -> @startSessionButton[0]
  asWidget: -> @sessionPanel[0]

## RepoListPresenter ##
# In charge of displaying a list of Repositories for the user to choose from 
# during the Start Session workflow.
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

## RepoListDisplay ##
# Displays a sexy list of repos for the presenter.  
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
    
## RepoListItemPresenter ##
# In charge of an individual Repository that lives in the RepoListPresenter,
# it's display and events.
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
      
      if @repo.fork
        @display.showForked()
    
  setRepo: (@repo) ->

## RepoListItemDisplay ##
# Visual representation of our little RepoListItemPresenter
class RepoListItemDisplay extends Display
  constructor: ->
    @panel = $ '<li></li>'

    @repoNameLabel = $ '<span></span>'
    @repoSiteLink = $ '<a href="javascript:void(0);"></a>'
    
    @repoNameLabel.appendTo @panel
    @repoSiteLink.appendTo @panel
    
    @repoFork = $ '<img src="https://github.com/images/modules/pagehead/repostat_forks.png" />'

  getNameLabel: -> @repoNameLabel
  getSiteLink: -> @repoSiteLink

  setName: (text) -> @repoNameLabel.text text
  setSiteLink: (link) -> @repoSiteLink.attr href: link
  setSiteText: (text) -> @repoSiteLink.text text
  showForked: -> @repoFork.prependTo @panel

  asWidget: -> @panel[0]

## GitHubRepo ##
# A Model class that represents a GitHub Repository.
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
    
## GitHubUser ##
# A Model class that represents a GitHub User.
class GitHubUser
  constructor: (@json) ->
    @id = @json.id
    @username = @json.login
    @gravatarUrl = @json.gravatar_url
    @githubUrl = @json.url
  
  
## GitHubService ##
# The GitHub API interaction object. Makes calls into the background page's 
# oauth object on behalf of the application. Add to me if you ever need to talk
# to GitHub.
class GitHubService
  
  @PRESS = 
    oauth: 'getOAuth'
  
  @INJECT =
    eventBus: 'getEventBus'
    logger: 'getLogger'
  
  ##### constructor ####
  # Builds a new GitHub service object with the api root provided
  constructor: (@oauth) ->
    @api_root = "https://api.github.com"
    
  ##### logout ####
  # Clears all OAuth Tokens stored for this application from localstorage.
  logout: -> @oauth.clearTokens()

  ##### startAuth ####
  # Start the OAuth flow in the gadget, fires the loginSuccess event on complete.
  startAuth: -> 
    @oauth.authorize =>
      @eventBus.fire "loginSuccess"
  
  ##### getUser ####
  # Gets the currently logged in user
  # 
  #  - callback {function} A Callback function that expects a *GitHubUser*
  getUser: (callback) ->
    @oauth.sendSignedRequest @apo_root + '/user', (responseText, xhr) =>
      jsonResult = @.parseJSON responseText
      callback new GitHubUser jsonResult
  
  ##### getUserRepoList ####
  # Gets all of the repos that the user has access to (private and public)
  # 
  #  - callback {function} A callback function that expects a list of *GitHubRepo*
  getUserRepoList: (callback) ->
    @oauth.sendSignedRequest @api_root + '/user/repos', (responseText, xhr) =>
      jsonResult = $.parseJSON responseText
      repos = (new GitHubRepo repo for repo in jsonResult)
      callback repos
  
  ##### loggedIn ####
  # A Check with the background page's oauth object to see if there are any
  # tokens living for our app.
  loggedIn: -> @oauth.hasToken()
  
  ##### inSession ####
  # A check to see if a Session has been started yet by the user.
  inSession: -> 

## Application ##
# The Application class brings together all of the initial services for
# the app, adds them to the EspressoMachine for future presenters to bind to.
# Then handles the initial call into the main presenter.
class Application
  
  esp = new EspressoMachine
  eventBus = new EventBus
  logger = new Logger
  hasRun = false
  
  run: ->
    # only run the application once
    if hasRun
      return
    hasRun = true
    
    # register some base services with the Espresso Machine
    esp.register('getEventBus', -> eventBus)
    esp.register('getLogger', -> logger)
    esp.register('getRootPanel', -> $('#application'))
    
    # create the singleton display classes and register with the Espresso Machine
    ghDisplay = new GitHubDisplay
    loginDisplay = new LoginDisplay
    repoListDisplay = new RepoListDisplay
    startSessionDisplay = new StartSessionDisplay
    
    esp.register 'GitHubDisplayType', -> ghDisplay
    esp.register 'LoginDisplayType', -> loginDisplay
    esp.register 'RepoListDisplayType', -> repoListDisplay
    esp.register 'StartSessionDisplayType', -> startSessionDisplay
    
    # create the factory display classes and register them with the Espresso Machine.
    esp.register 'RepoListItemDisplayType', -> new RepoListItemDisplay  
    
    # reach into the background.html page for the oauth info &
    # register the chrome extension's oauth with the Espresso Machine
    backgroundPage = chrome.extension.getBackgroundPage()
    esp.register('getOAuth', -> backgroundPage.oauth)
    
    # press the GitHub service which relies on the oauth, then register it
    # with the Espresso Machine.
    gh = esp.create(GitHubService)
    esp.register 'getService', -> gh

    # Create and register the initial presenters that the GitHub Presenter
    # needs to start up the application.
    loginPresenter = esp.create LoginPresenter
    esp.register 'getLoginPresenter', -> loginPresenter
    
    repoListPresenter = esp.create RepoListPresenter
    esp.register 'getRepoListPresenter', -> repoListPresenter
    
    startSessionPresnter = esp.create StartSessionPresenter
    esp.register 'getStartSessionPresenter', -> startSessionPresnter
    
    # Finally, start your engines and bind the main presenter.
    ghPresenter = esp.create GitHubPresenter
    ghPresenter.bind()
    
    # Add the main presenter's widget to the RootPanel
    esp.getRootPanel().empty()
    esp.getRootPanel().append ghPresenter.getDisplay().asWidget()


@ready =>
  @app = new Application()
  @app.run()