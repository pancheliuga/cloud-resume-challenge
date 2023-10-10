/// <reference types="cypress" />

describe("Resume", () => {
    beforeEach(() => {
      cy.visit("/");
    });
  
    it("should contain the name of the resume owner", () => {
      cy.get("h1").should("contain", "Oleksandr Pancheliuga");
    });
  
    it("should return the view count when visited", () => {
      cy.get("#views").then((content) => {
        var views = parseInt(content[0].innerText);
        cy.wrap(views).should("be.a", "number");
      });
    });
  });