/// <reference types="cypress" />

describe("POST", () => {
    it("should return the view count in its response body", () => {
      // https://on.cypress.io/request
      cy.request({
        method: "POST",
        url: `${Cypress.env('api')}`,
      }).should((response) => {
        expect(response.status).to.eq(200);
        var views = JSON.parse(response.body);
        expect(views).to.be.at.least(1)
      });
    });
  });