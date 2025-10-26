# frozen_string_literal: true

require "spec_helper"

describe "Decidim::Shakapacker" do
  let(:package_json) { Rails.root.join("package.json") }
  let(:yarn_lock) { Rails.root.join("yarn.lock") }

  it "should have a valid package.json" do
    expect(package_json).to be_truthy
  end

  it "should have a valid yarn.lock" do
    expect(yarn_lock).to be_truthy
  end

  context "when runningyarn audit" do
    let(:audit_summaries) do
      Dir.chdir(Rails.root) do
        jsonl_output = `yarn audit ---no-progress --json --frozen-lockfile --non-interactive --groups "dependencies,optionalDependencies" 2>&1`
        command_result = jsonl_output.strip.split("\n").map { |line| JSON.parse(line.strip) }
        command_result.select { |result| result["type"] == "auditSummary" }
      end
    end

    let(:critical_vulnerabilities) do
      audit_summaries.reduce(0) { |sum, result| sum + result["data"]["vulnerabilities"]["critical"] }
    end
    let(:high_vulnerabilities) do
      audit_summaries.reduce(0) { |sum, result| sum + result["data"]["vulnerabilities"]["high"] }
    end

    it "should have no critical vulnerabilities" do
      expect(critical_vulnerabilities).to be_zero
    end

    it "should have no high vulnerabilities" do
      expect(high_vulnerabilities).to be_zero
    end
  end
end
