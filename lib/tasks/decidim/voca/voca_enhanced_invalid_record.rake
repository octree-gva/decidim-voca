# frozen_string_literal: true

def voca_orphan?(resource, relation_sym)
  !resource.public_send(relation_sym)
rescue StandardError
  # Any error while accessing the relation means it is unsafe -> consider orphaned.
  true
end

def voca_delete_orphans(model, relation_sym)
  deleted = 0
  model.find_each do |resource|
    next unless voca_orphan?(resource, relation_sym)

    resource.delete
    deleted += 1
  end
  deleted
end

VOCA_RELATION_CHECKS = [
  # --- CommentableWithComponent ---
  ["Decidim::Meetings::Meeting", :component],
  ["Decidim::Meetings::Meeting", :author],
  ["Decidim::Debates::Debate", :component],
  ["Decidim::Debates::Debate", :author],
  ["Decidim::Proposals::Proposal", :component],
  ["Decidim::Proposals::CollaborativeDraft", :component],
  ["Decidim::Blogs::Post", :component],
  ["Decidim::Blogs::Post", :author],
  ["Decidim::Budgets::Project", :budget],
  ["Decidim::Sortitions::Sortition", :component],
  ["Decidim::Sortitions::Sortition", :decidim_proposals_component],
  ["Decidim::Accountability::Result", :component],
  ["Decidim::Accountability::Status", :component],
  ["Decidim::Accountability::TimelineEntry", :result],

  # --- Meetings: registrations, invites, poll, agenda, services ---
  ["Decidim::Meetings::Registration", :meeting],
  ["Decidim::Meetings::Registration", :user],
  ["Decidim::Meetings::Invite", :meeting],
  ["Decidim::Meetings::Invite", :user],
  ["Decidim::Meetings::Poll", :meeting],
  ["Decidim::Meetings::Service", :meeting],
  ["Decidim::Meetings::Agenda", :meeting],
  ["Decidim::Meetings::AgendaItem", :agenda],

  # --- Meetings questionnaires (registration form + live poll) ---
  ["Decidim::Meetings::Questionnaire", :questionnaire_for],
  ["Decidim::Meetings::Question", :questionnaire],
  ["Decidim::Meetings::Answer", :questionnaire],
  ["Decidim::Meetings::Answer", :question],
  ["Decidim::Meetings::AnswerOption", :question],
  ["Decidim::Meetings::AnswerChoice", :answer],
  ["Decidim::Meetings::AnswerChoice", :answer_option],

  # --- Surveys / generic forms (Decidim::Forms) ---
  ["Decidim::Surveys::Survey", :component],
  ["Decidim::Surveys::Survey", :questionnaire],
  ["Decidim::Forms::Questionnaire", :questionnaire_for],
  ["Decidim::Forms::Question", :questionnaire],
  ["Decidim::Forms::AnswerOption", :question],
  ["Decidim::Forms::QuestionMatrixRow", :question],
  ["Decidim::Forms::DisplayCondition", :question],
  ["Decidim::Forms::DisplayCondition", :condition_question],
  ["Decidim::Forms::Answer", :questionnaire],
  ["Decidim::Forms::Answer", :question],
  ["Decidim::Forms::AnswerChoice", :answer],
  ["Decidim::Forms::AnswerChoice", :answer_option],

  # --- Comments ---
  ["Decidim::Comments::Comment", :commentable],
  ["Decidim::Comments::Comment", :root_commentable],
  ["Decidim::Comments::CommentVote", :comment],
  ["Decidim::Comments::CommentVote", :author],

  # --- Proposals children (common orphans) ---
  ["Decidim::Proposals::ProposalVote", :proposal],
  ["Decidim::Proposals::ProposalVote", :author],
  ["Decidim::Proposals::ProposalNote", :proposal],
  ["Decidim::Proposals::ProposalNote", :author],
  ["Decidim::Proposals::CollaborativeDraftCollaboratorRequest", :collaborative_draft],
  ["Decidim::Proposals::CollaborativeDraftCollaboratorRequest", :user],

  # --- Core / other ---
  ["Decidim::Pages::Page", :component],
  ["Decidim::Coauthorship", :coauthorable],
  ["Decidim::Coauthorship", :author],
  ["Decidim::Attachment", :attached_to],
  ["Decidim::AttachmentCollection", :collection_for],
  ["Decidim::Follow", :followable],
  ["Decidim::Follow", :user],
  ["Decidim::Report", :moderation],
  ["Decidim::Report", :user],
  ["Decidim::Moderation", :reportable],
  ["Decidim::UserReport", :user],
  ["Decidim::UserReport", :moderation],
  ["Decidim::ResourceLink", :from],
  ["Decidim::ResourceLink", :to],
  ["Decidim::Proposals::ProposalState", :component],
  ["Decidim::ParticipatorySpacePrivateUser", :privatable_to],
  ["Decidim::Notification", :resource],
  ["Decidim::Notification", :user]
].freeze

if Rake::Task.task_defined?("decidim:upgrade:clean:invalid_records")
  Rake::Task["decidim:upgrade:clean:invalid_records"].enhance do
    puts("=== Deleting VOCA orphaned records")

    total_deleted = 0

    VOCA_RELATION_CHECKS.each do |model_name, relation_sym|
      model = model_name.safe_constantize

      next unless model

      puts("==== Deleting invalid #{model_name} (missing #{relation_sym})")
      deleted = voca_delete_orphans(model, relation_sym)
      total_deleted += deleted
      puts("===== Deleted #{deleted} invalid #{model_name}")
    end

    puts("=== Deleted #{total_deleted} VOCA orphaned records")
  end
else
  puts("=== VOCA orphan cleanup skipped (decidim:upgrade:clean:invalid_records not defined)")
end
