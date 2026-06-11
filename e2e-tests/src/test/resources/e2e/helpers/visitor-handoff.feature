@ignore
Feature: Helper — Generar QR handoff para visitante (auth-service)

  Scenario: Generar visitor handoff
    Given url baseUrlAuth
    And path '/api/v1/auth/visitor/handoff'
    And header Authorization = 'Bearer ' + jwt
    And request { anonymousId: '#(visitorAnonId)' }
    When method POST
    Then assert responseStatus == 200 || responseStatus == 201
    * def handoffToken = response.token || response.qrToken || ''
    * karate.log('Handoff token generado para visitante')
