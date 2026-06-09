@ignore
Feature: Helper — Login a auth-service y obtener JWT + anonymousId

  Scenario: Login con credenciales
    Given url baseUrlAuth
    And path '/api/v1/auth/login'
    And request { username: '#(username)', password: '#(password)' }
    When method POST
    Then status 200
    And match response.token == '#notnull'
    And match response.anonymousId == '#notnull'
    * def jwt = response.token
    * def anonId = response.anonymousId
