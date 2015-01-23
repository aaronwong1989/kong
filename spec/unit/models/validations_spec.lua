local utils = require "apenode.tools.utils"
local BaseModel = require "apenode.models.base_model"
local configuration = {
  database = "sqlite",
  databases_available = {
    sqlite = { properties = { memory = true } }
  }
}

local configuration, dao_factory = utils.load_configuration_and_dao(configuration)

-- Ok kids, today we're gonna test a custom validation schema,
-- grab a pair of glasses, this stuff can literally explode.
local collection = "custom_object"
local validator = {
  id = { type = "number",
         read_only = true },

  string = { type = "string",
             required = true,
             func = check_account_id },

  url = { type = "string",
          required = true,
          regex = "(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])" },

  date = { type = "timestamp",
           default = 123456 },

  default = { type = "string",
              default = function() return "default" end  },

  number = { type = "number",
             func = function(n) if n == 123 then return true else return false, "The value should be 123" end end },

  table = { type = "table",
            schema_from_func = function() return { smart = { type = "boolean" }} end }
}

describe("Validation", function()

  setup(function()
    dao_factory:prepare()
  end)

  describe("#validate()", function()

    it("should confirm a valid entity is valid", function()
      local values = { string = "httpbin entity", url = "httpbin.org" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(err)
      assert.truthy(res_values)
    end)

    it("should set default values if those are variables or functions specified in the validator", function()
      -- Variables
      local values = { string = "httpbin entity", url = "httpbin.org" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(err)
      assert.truthy(res_values)
      assert.are.same(123456, res_values.date)

      -- Functions
      local values = { string = "httpbin entity", url = "httpbin.org" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(err)
      assert.truthy(res_values)
      assert.are.same("default", res_values.default)
    end)

    it("should override default values if specified", function()
      -- Variables
      local values = { string = "httpbin entity", url = "httpbin.org", date = 654321 }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(err)
      assert.truthy(res_values)
      assert.are.same(654321, res_values.date)

      -- Functions
      local values = { string = "httpbin entity", url = "httpbin.org", default = "abcdef" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(err)
      assert.truthy(res_values)
      assert.are.same("abcdef", res_values.default)
    end)

    it("should validate a field against a regex", function()
      local values = { string = "httpbin entity", url = "httpbin_!" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(res_values)
      assert.are.same("url has an invalid value", err.url)
    end)

    it("should return error when unexpected values are included in the schema", function()
      local values = { string = "httpbin entity", url = "httpbin.org", unexpected = "abcdef" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(res_values)
      assert.are.same("unexpected is an unknown field", err.unexpected)
    end)

    it("should validate against a custom function", function()
      -- Success
      local values = { string = "httpbin entity", url = "httpbin.org", number = 123 }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(err)
      assert.truthy(res_values)

      -- Error
      local values = { string = "httpbin entity", url = "httpbin.org", number = 456 }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(res_values)
      assert.are.same("The value should be 123", err.number)
    end)

    it("should return errors if trying to pass read_only properties", function()
      local values = { id = 1, string = "httpbin entity", url = "httpbin.org" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(res_values)
      assert.truthy(err)
      assert.are.same("id is read only", err.id)
    end)

    it("should be able to return multiple errors at once", function()
      local values = { id = 1, string = "httpbin entity", url = "httpbin.org", unexpected = "abcdef" }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()
      assert.falsy(res_values)
      assert.truthy(err)
      assert.are.same("id is read only", err.id)
      assert.are.same("unexpected is an unknown field", err.unexpected)
    end)
    --[[
    it("should validate a nested schema", function()
      -- Success
      local values = { id = 1, string = "httpbin entity", url = "httpbin.org", table = { smart = true } }
      local model = BaseModel(collection, validator, values, dao_factory)

      local res_values, err = model:validate()

    end)
    --]]
  end)
end)
